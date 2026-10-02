#!/usr/bin/env bash
# Appele par Terraform au destroy : vide un bucket versionne (toutes les
# versions et marqueurs de suppression) puis le supprime. Idempotent.
set -euo pipefail
B="$1"
aws s3api head-bucket --bucket "$B" 2>/dev/null || { echo "Bucket $B absent : rien a faire"; exit 0; }
while :; do
  payload=$(aws s3api list-object-versions --bucket "$B" --output json | python3 -c '
import sys, json
d = json.load(sys.stdin)
o = [{"Key": x["Key"], "VersionId": x["VersionId"]} for x in d.get("Versions", []) + d.get("DeleteMarkers", [])][:1000]
print(json.dumps({"Objects": o, "Quiet": True}) if o else "")')
  [ -z "$payload" ] && break
  aws s3api delete-objects --bucket "$B" --delete "$payload" >/dev/null
done
aws s3api delete-bucket --bucket "$B"
echo "Bucket $B vide et supprime"
