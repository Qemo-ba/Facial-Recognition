"""
Autor: Aldin
Datum: 17.03.2026
Quelle: https://docs.aws.amazon.com/rekognition/latest/dg/celebrities.html
Beschreibung: Backend-Logik für den Face Recognition Service. Diese Funktion wird
durch einen S3-Upload getriggert, analysiert das Foto auf bekannte Persönlichkeiten
und speichert das Ergebnis als JSON im Out-Bucket.
"""

import json
import os
import urllib.parse

import boto3

s3_client = boto3.client("s3")
rekognition_client = boto3.client("rekognition")

OUT_BUCKET_NAME = os.environ["OUT_BUCKET_NAME"]


def lambda_handler(event, context):
    try:
        # Bucket-Name und Object Key aus dem S3-Event auslesen
        record = event["Records"][0]
        bucket_name = record["s3"]["bucket"]["name"]
        object_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        print(f"Neues Bild erkannt: s3://{bucket_name}/{object_key}")

        # Amazon Rekognition aufrufen
        try:
            response = rekognition_client.recognize_celebrities(
                Image={
                    "S3Object": {
                        "Bucket": bucket_name,
                        "Name": object_key,
                    }
                }
            )
        except Exception as e:
            print(f"Fehler beim Aufruf von Rekognition: {e}")
            raise

        # Ergebnis auswerten
        celebrity_faces = response.get("CelebrityFaces", [])

        if not celebrity_faces:
            print("Keine Prominenten im Bild erkannt.")
            result = {
                "Message": "Keine Prominenten erkannt.",
                "SourceImage": object_key,
            }
        else:
            celebrity = celebrity_faces[0]
            face_detail = celebrity.get("Face", {})

            result = {
                "Id": celebrity.get("Id"),
                "Name": celebrity.get("Name"),
                "MatchConfidence": celebrity.get("MatchConfidence"),
                "KnownGender": celebrity.get("KnownGender", {}).get("Type"),
                "Smile": face_detail.get("Smile", {}).get("Value"),
            }

            print(f"Erkannter Prominenter: {result['Name']} "
                  f"(Confidence: {result['MatchConfidence']}%)")

        # Ergebnis als JSON im Out-Bucket speichern
        output_key = object_key.rsplit(".", 1)[0] + ".json"

        try:
            s3_client.put_object(
                Bucket=OUT_BUCKET_NAME,
                Key=output_key,
                Body=json.dumps(result, indent=2),
                ContentType="application/json",
            )
            print(f"Ergebnis gespeichert: s3://{OUT_BUCKET_NAME}/{output_key}")
        except Exception as e:
            print(f"Fehler beim Speichern im Out-Bucket: {e}")
            raise

        return {
            "statusCode": 200,
            "body": json.dumps(result),
        }

    except Exception as e:
        print(f"Unerwarteter Fehler: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }
