{{/*
Common name helpers.
*/}}
{{- define "rumbles.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "rumbles.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" (include "rumbles.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "rumbles.labels" -}}
app.kubernetes.io/name: {{ include "rumbles.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "rumbles.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rumbles.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Resolve the container image reference.
Enterprise posture: deploy STRICTLY by immutable digest. If the digest is
missing we FAIL the render rather than fall back to a mutable tag — a mutable
tag defeats the point of immutability. The `tag` value is kept elsewhere only
as human-readable metadata (which commit an image came from), never for pulling.
*/}}
{{- define "rumbles.image" -}}
{{- if not .Values.image.repository -}}
{{- fail "image.repository is required" -}}
{{- end -}}
{{- if not .Values.image.digest -}}
{{- fail "image.digest is required — refusing to deploy by mutable tag. The pipeline must pin an immutable @sha256 digest." -}}
{{- end -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- end -}}
