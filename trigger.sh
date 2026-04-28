#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")"
echo "$(date)" >> .trigger
git add .trigger && git commit -m "test: trigger argocd sync" && git push
