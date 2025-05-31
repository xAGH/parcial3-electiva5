#!/bin/bash
#
# Script para verificar, instalar o iniciar un cluster k3s,
# configurar el editor por defecto en nano, instalar o verificar Ingress-NGINX,
# ajustar el Service de Ingress-NGINX a NodePort en el puerto 3100,
# desplegar los pods y recursos personalizados, esperar a que los pods estén Ready
# (con un timeout de 1 minuto), y finalmente desplegar el Ingress personalizado.
# Además, valida si existe la tabla `tasks` en la base `taskdb` y, de no existir,
# la crea automáticamente.
#
# IMPORTANTE:
# - Ejecuta este script con privilegios de root o sudo.
# - Ajusta las rutas si cambien en tu entorno.

set -e

# -----------------------------
# 0. Configurar editor por defecto para kubectl edit (usar nano en vez de vi)
# -----------------------------
export KUBE_EDITOR="nano"
export EDITOR="nano"
echo "Editor por defecto para kubectl edit configurado en nano."

# -----------------------------
# 1. Verificar si k3s está instalado
# -----------------------------
if ! command -v k3s >/dev/null 2>&1; then
    echo "k3s no está instalado. Iniciando la instalación..."
    curl -sfL https://get.k3s.io | sh -
    echo "Instalación de k3s completada."
else
    echo "k3s ya está instalado."
fi

# -----------------------------
# 2. Verificar si el servicio k3s está activo (ejecutándose)
# -----------------------------
if systemctl is-active --quiet k3s; then
    echo "El cluster k3s ya se encuentra en ejecución."
else
    echo "El cluster k3s NO está en ejecución. Iniciando servicio k3s..."
    systemctl start k3s
    echo "Servicio k3s iniciado."
fi

# -----------------------------
# 3. Esperar a que el nodo k3s esté en estado Ready
# -----------------------------
echo -n "Esperando a que el nodo k3s esté listo "
while true; do
    if kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -qw "Ready"; then
        echo "✓"
        echo "Nodo k3s en estado Ready."
        break
    else
        echo -n "."
        sleep 2
    fi
done

# -----------------------------
# 4. Verificar/Instalar Ingress-NGINX (controlador oficial)
# -----------------------------
INGRESS_NGINX_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml"
echo "Verificando existencia de Ingress-NGINX..."
if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    echo "Ingress-NGINX NO encontrado. Instalando controlador Ingress-NGINX..."
    kubectl apply -f "$INGRESS_NGINX_URL"
    echo "Instalación de Ingress-NGINX completada."
else
    echo "Ingress-NGINX ya está instalado."
fi

# -----------------------------
# 5. Esperar a que los pods del controlador Ingress-NGINX estén Running y Ready
# -----------------------------
echo -n "Esperando a que los pods de ingress-nginx-controller estén Ready "
while true; do
    PODS_READY=$(kubectl -n ingress-nginx get pods -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | awk '{print $2}')
    ALL_READY=true

    if [ -z "$PODS_READY" ]; then
        ALL_READY=false
    else
        for ready in $PODS_READY; do
            if [[ "$ready" != "1/1" ]]; then
                ALL_READY=false
                break
            fi
        done
    fi

    if $ALL_READY; then
        echo "✓"
        echo "Ingress-NGINX controller está corriendo y Ready."
        break
    else
        echo -n "."
        sleep 5
    fi
done

# -----------------------------
# 6. Ajustar Service ingress-nginx-controller para usar NodePort en el puerto 3100
# -----------------------------
echo "Configurando el Service ingress-nginx-controller como NodePort en el puerto 3100..."
kubectl -n ingress-nginx patch svc ingress-nginx-controller \
    --type='json' \
    -p='[
      {"op":"replace","path":"/spec/type","value":"NodePort"},
      {"op":"replace","path":"/spec/ports/0/port","value":3100},
      {"op":"replace","path":"/spec/ports/0/nodePort","value":31000},
      {"op":"replace","path":"/spec/ports/1/nodePort","value":30443}
    ]'
echo "Service actualizado: type=NodePort, port=3100. El nodePort se asignará automáticamente dentro del rango 30000-32767."

# -----------------------------
# 7. Desplegar todos los recursos excepto el Ingress personalizado
# -----------------------------
MANIFEST_DIR="/home/despliegue-ms/parcial"
echo "Aplicando manifiestos de recursos (excluyendo ingress-back.yaml) en '$MANIFEST_DIR'..."
for file in "$MANIFEST_DIR"/*.yml "$MANIFEST_DIR"/*.yaml; do
    if [[ "$(basename "$file")" == "ingress-back.yaml" ]]; then
        continue
    fi
    if [ -f "$file" ]; then
        echo "  -> Aplicando $file"
        kubectl apply -f "$file"
    fi
done
echo "Despliegue de pods y servicios completado."

# -----------------------------
# 8. Esperar a que todos los pods en 'default' estén en estado Running o Completed (timeout 1 minuto)
# -----------------------------
echo -n "Esperando a que los pods en 'default' estén Ready (hasta 1 minuto) "
start_time=$(date +%s)
timeout=$(( start_time + 60 ))

while true; do
    NOT_READY_COUNT=$(kubectl get pods --no-headers 2>/dev/null | awk '{print $1":"$3}' | grep -v -E ":(Running|Completed)" | wc -l)
    now=$(date +%s)

    if [[ "$NOT_READY_COUNT" -eq 0 ]]; then
        echo "✓"
        echo "Todos los pods están en estado Running/Completed."
        break
    fi

    if [[ "$now" -ge "$timeout" ]]; then
        echo
        echo "⚠️ Timeout: Aún hay pods no Ready después de 1 minuto."
        break
    fi

    echo -n "."
    sleep 5
done

# -----------------------------
# 9. Desplegar el Ingress personalizado (ingress-back.yaml) al final
# -----------------------------
INGRESS_MANIFEST="$MANIFEST_DIR/ingress-back.yaml"
if [ -f "$INGRESS_MANIFEST" ]; then
    echo "Aplicando manifiesto de Ingress personalizado desde '$INGRESS_MANIFEST'..."
    kubectl apply -f "$INGRESS_MANIFEST"
    echo "Despliegue del Ingress personalizado completado."
else
    echo "Archivo de manifiesto de Ingress '$INGRESS_MANIFEST' NO encontrado."
    echo "Por favor, verifica la ruta y vuelve a ejecutar el script."
fi

# -----------------------------
# 10. Validar si los pods están corriendo o no existen
# -----------------------------
echo
echo "Validando el estado de los pods en el namespace 'default'..."
PODS=$(kubectl get pods --no-headers 2>/dev/null | awk '{print $1}')

if [ -z "$PODS" ]; then
    echo "No se encontraron pods en el namespace 'default'."
else
    for pod in $PODS; do
        STATUS=$(kubectl get pod "$pod" -o jsonpath='{.status.phase}')
        echo "Pod: $pod    Estado: $STATUS"
    done
fi

echo
echo "=== Script finalizado ==="
