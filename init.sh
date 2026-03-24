#!/bin/bash

# ==========================================
# ERROR HANDLING (Fehlerüberprüfung)
# ==========================================
set -e
export AWS_PAGER=""

error_handler() {
    echo "=========================================="
    echo "❌ FEHLER: Setup abgebrochen!"
    echo "Ein Befehl ist fehlgeschlagen. Bitte überprüfe die Fehlermeldung oben."
    echo "=========================================="
}
trap 'error_handler' ERR

# ==========================================
# Projekt: Modul 346 - Promi-Erkennung
# Autor: Qemal 
# Datum: 17.03.2026
# Beschreibung: Initialisiert die AWS Umgebung
# ==========================================

echo "Starte AWS-Infrastruktur-Setup..."

IN_BUCKET="promi-in-bucket-gruppe-123456"
OUT_BUCKET="promi-out-bucket-gruppe-123456"
ROLE_NAME="LabRole" 
LAMBDA_NAME="PromiErkennerDemo"
REGION="us-east-1" 

echo "Erstelle S3 Buckets in Region $REGION..."
aws s3 mb s3://$IN_BUCKET --region $REGION
aws s3 mb s3://$OUT_BUCKET --region $REGION

echo "Hole Berechtigungen (LabRole)..."
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)


echo "Verpacke den Python-Code in ein ZIP-Archiv..."
zip function.zip lambda_function.py

echo "Erstelle Lambda Funktion..."
aws lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime python3.12 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{OUT_BUCKET_NAME=$OUT_BUCKET}"

# Erlaubnis geben, dass der In-Bucket die Lambda triggern darf
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --principal s3.amazonaws.com \
    --statement-id s3invoke \
    --action "lambda:InvokeFunction" \
    --source-arn arn:aws:s3:::$IN_BUCKET

echo "Richte S3 Event Trigger ein..."
cat > notification.json << EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "TriggerWennBildHochgeladen",
      "LambdaFunctionArn": "$(aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text)",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration --bucket $IN_BUCKET --notification-configuration file://notification.json

# Aufräumen der lokalen Hilfsdateien (inklusive der generierten ZIP-Datei)
rm notification.json function.zip

trap - ERR 

echo "=========================================="
echo "✅ SETUP ERFOLGREICH ABGESCHLOSSEN!"
echo "Verwendete Komponenten:"
echo "- In-Bucket:  $IN_BUCKET"
echo "- Out-Bucket: $OUT_BUCKET"
echo "- IAM-Rolle:  $ROLE_NAME"
echo "- Lambda:     $LAMBDA_NAME"
echo "=========================================="