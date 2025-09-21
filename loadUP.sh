#!/usr/bin/env bash
# deploy_arTest.sh
# Wipe and redeploy your demo to S3 with correct MIME types and “no-cache” on HTML.
# Usage: bash deploy_arTest.sh
# Optional: set CF_DIST_ID to invalidate a CloudFront distribution after upload.

set -euo pipefail

# --- edit these if needed ---
BUCKET="dan-monaghan.com"
PREFIX="arTest"                 # ends up at s3://$BUCKET/$PREFIX/
SRC_HTML="examples/public"      # your HTML lives here
SRC_DIST="dist"                 # optional: built bundles
SRC_SRC="src"                   # optional: source JS/CSS/assets
CF_DIST_ID="${CF_DIST_ID:-}"    # set env var if you want a CloudFront invalidation
# ----------------------------

echo "› Checking tools…"
command -v aws >/dev/null || { echo "aws CLI not found"; exit 1; }

S3_BASE="s3://${BUCKET}/${PREFIX}"

echo "› Removing old objects at ${S3_BASE}/ …"
aws s3 rm "${S3_BASE}/" --recursive || true

echo "› Sync HTML (and assets under it)…"
if [[ -d "${SRC_HTML}" ]]; then
  aws s3 sync "${SRC_HTML}/" "${S3_BASE}/" --exact-timestamps
else
  echo "!! ${SRC_HTML} not found"; exit 1
fi

if [[ -d "${SRC_DIST}" ]]; then
  echo "› Sync dist/ …"
  aws s3 sync "${SRC_DIST}/" "${S3_BASE}/dist/" --exact-timestamps
fi

if [[ -d "${SRC_SRC}" ]]; then
  echo "› Sync src/ …"
  aws s3 sync "${SRC_SRC}/" "${S3_BASE}/src/" --exact-timestamps
fi

echo "› Forcing correct headers on HTML (no-cache + text/html)…"
# Re-upload only .html files with explicit metadata to defeat iOS/Safari caching
# and ensure Content-Type is correct even behind proxies/CDNs.
while IFS= read -r -d '' f; do
  rel="${f#${SRC_HTML}/}"               # path under SRC_HTML
  key="${PREFIX}/${rel}"                # final key under arTest/
  echo "   * ${key}"
  aws s3 cp "${f}" "s3://${BUCKET}/${key}" \
    --content-type "text/html; charset=utf-8" \
    --cache-control "no-cache, no-store, must-revalidate" \
    --metadata-directive REPLACE
done < <(find "${SRC_HTML}" -type f -name "*.html" -print0)

# (Optional) If you know you want long-cache on JS/CSS, uncomment below:
# echo "› (Optional) Setting long cache on JS/CSS…"
# while IFS= read -r -d '' jf; do
#   rel="${jf#${SRC_HTML}/}"; key="${PREFIX}/${rel}"
#   aws s3 cp "s3://${BUCKET}/${key}" "s3://${BUCKET}/${key}" \
#     --content-type "application/javascript" \
#     --cache-control "max-age=31536000, immutable" \
#     --metadata-directive REPLACE
# done < <(find "${SRC_HTML}" -type f -name "*.js" -print0)

# while IFS= read -r -d '' cf; do
#   rel="${cf#${SRC_HTML}/}"; key="${PREFIX}/${rel}"
#   aws s3 cp "s3://${BUCKET}/${key}" "s3://${BUCKET}/${key}" \
#     --content-type "text/css" \
#     --cache-control "max-age=31536000, immutable" \
#     --metadata-directive REPLACE
# done < <(find "${SRC_HTML}" -type f -name "*.css" -print0)

if [[ -n "${CF_DIST_ID}" ]]; then
  echo "› Creating CloudFront invalidation for /${PREFIX}/* on ${CF_DIST_ID} …"
  aws cloudfront create-invalidation \
    --distribution-id "${CF_DIST_ID}" \
    --paths "/${PREFIX}/*" >/dev/null
  echo "  (CloudFront invalidation submitted)"
fi

echo
echo "✅ Deployed."
echo "Test on iPhone: https://${BUCKET}/${PREFIX}/index.html"
echo "Or any page you pushed from ${SRC_HTML}/ (e.g., imu.html, camera.html)."

