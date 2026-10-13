#!/usr/bin/env bash
# Publica la carpeta de un build en la rama gh-pages (la que sirve GitHub Pages).
#
# Uso: scripts/publish-pages.sh <carpeta del build> <tag>
#
# Cada build va en su propia carpeta (<tag>/) y la portada se regenera con todos.
# La rama tiene un único commit que se reemplaza en cada publicación, para que los
# IPA borrados no se acumulen en el historial. Si otro build publica a la vez, el
# push se rechaza (--force-with-lease) y se vuelve a intentar sobre su versión.
#
# Variables opcionales: PAGES_BRANCH (gh-pages), PAGES_KEEP_BRANCH_BUILDS (50),
# PAGES_TITLE y REPO_URL.
set -euo pipefail

build_dir=$1
tag=$2
branch=${PAGES_BRANCH:-gh-pages}
keep=${PAGES_KEEP_BRANCH_BUILDS:-50}
script_dir=$(cd "$(dirname "$0")" && pwd)
git_dir=$(git rev-parse --absolute-git-dir)

work=$(mktemp -d)
index_file=$(mktemp)
trap 'rm -rf "$work" "$index_file"' EXIT

for attempt in 1 2 3 4 5 6; do
  rm -rf "$work" && mkdir -p "$work"

  if git fetch --quiet origin "refs/heads/$branch" 2>/dev/null; then
    remote=$(git rev-parse FETCH_HEAD)
    git archive FETCH_HEAD | tar -x -C "$work"
  else
    remote=""
    echo "La rama $branch no existe todavía: se crea."
  fi

  # Solo se conservan las carpetas de builds (con build.json); lo demás (p. ej. código
  # si la rama se creó a partir de main) se descarta y la portada se regenera.
  for entry in "$work"/* "$work"/.[!.]*; do
    [ -e "$entry" ] || continue
    if [ ! -f "$entry/build.json" ]; then rm -rf "$entry"; fi
  done
  rm -rf "${work:?}/$tag"
  cp -R "$build_dir" "$work/$tag"
  python3 "$script_dir/adhoc.py" index \
    --site-dir "$work" \
    --keep-branch-builds "$keep" \
    --title "${PAGES_TITLE:-Leonera Keyboard}" \
    --repo-url "${REPO_URL:-}"

  rm -f "$index_file"
  tree=$(cd "$work" && export GIT_DIR=$git_dir GIT_WORK_TREE=$work GIT_INDEX_FILE=$index_file \
    && git add -A --force && git write-tree)
  commit=$(git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit-tree "$tree" -m "Publicar $tag")

  if git push --quiet --force-with-lease="refs/heads/$branch:$remote" origin "$commit:refs/heads/$branch"; then
    echo "Publicado $tag en $branch (intento $attempt)."
    exit 0
  fi
  echo "Otro build publicó a la vez; se reintenta…"
  sleep $((attempt * 5))
done

echo "::error::No se pudo publicar $tag en $branch."
exit 1
