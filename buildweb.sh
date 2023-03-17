dir="./docs/"

flutter build web -o "$dir" --web-renderer canvaskit --base-href "/crop_image/"
cp "${dir}index.html" "${dir}404.html"