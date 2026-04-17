{{/*
Selector labels — Deployment의 selector.matchLabels와 Pod template label에 동일 적용.
같은 set이어야 selector가 매칭됨.
*/}}
{{- define "ticketing.selectorLabels" -}}
app: {{ .name }}
{{- end -}}

{{/*
Common labels — 메타데이터/조회용. selector에는 들어가지 않음.
*/}}
{{- define "ticketing.commonLabels" -}}
app: {{ .name }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/part-of: ticketing
app.kubernetes.io/managed-by: {{ .root.Release.Service | default "Helm" }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end -}}

{{/*
이미지 풀 패스. .Values.images.<key> 의 repository:tag 조합.
*/}}
{{- define "ticketing.imageRef" -}}
{{- $img := index .root.Values.images .imageKey -}}
{{- printf "%s:%s" $img.repository (toString $img.tag) -}}
{{- end -}}
