#!/bin/bash

# 1. Variablen vom Benutzer abfragen
read -p "Wie heisst das Bild genau (inkl. Dateiendung, z.B. einstein.jpg)? " IMAGE_FILE
IN_BUCKET="promi-in-bucket-gruppe-123456"
OUT_BUCKET="promi-out-bucket-gruppe-123456"
echo ""
echo "Input Bucket: ${IN_BUCKET}"
echo "Output Bucket: ${OUT_BUCKET}"
echo ""

# Dateinamen ohne Endung extrahieren (um den .json Dateinamen zu generieren)
FILENAME="${IMAGE_FILE%.*}"
JSON_FILE="${FILENAME}.json"

echo "----------------------------------------"
echo "Starte Upload von ${IMAGE_FILE} in s3://${IN_BUCKET}/..."
aws s3 cp "${IMAGE_FILE}" "s3://${IN_BUCKET}/"

echo "----------------------------------------"
echo "Warte 5 Sekunden auf die Verarbeitung durch AWS Lambda..."
sleep 5

echo "----------------------------------------"
echo "Prüfe den Inhalt des Output-Buckets:"
aws s3 ls "s3://${OUT_BUCKET}/"

echo "----------------------------------------"
echo "Lade das Ergebnis (${JSON_FILE}) herunter..."
aws s3 cp "s3://${OUT_BUCKET}/${JSON_FILE}" .

echo "----------------------------------------"
# Prüfen, ob die Datei erfolgreich heruntergeladen wurde
if [ -f "${JSON_FILE}" ]; then
    echo "Ergebnis erfolgreich geladen! Hier ist der Inhalt:"
    cat "${JSON_FILE}"
    echo "" # Leere Zeile für bessere Lesbarkeit
else
    echo "Fehler: Die Datei ${JSON_FILE} wurde nicht gefunden."
    echo "Möglicherweise braucht die Lambda-Funktion länger, oder es gab einen Fehler in der Ausführung."
fi
echo "----------------------------------------"