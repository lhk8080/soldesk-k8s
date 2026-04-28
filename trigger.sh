#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")"
echo "$(date)" >> charts/ticketing/.trigger
git add charts/ticketing/.trigger && git commit -m "test: trigger argocd sync" && git push
