# CloudWatch Logs Insights — Detection Queries
Log group: /lab/cloudtrail

## A. Instance role activity by source IP (credential exfiltration)
    fields @timestamp, eventName, sourceIPAddress, userIdentity.arn
    | filter userIdentity.arn like /lab-app-role/
    | sort @timestamp desc

Instance SSM calls come from the instance IP; stolen-credential use appears
from an external IP. That IP mismatch is the detection.

## B. S3 enumeration / access by the instance role
    fields @timestamp, eventName, sourceIPAddress, requestParameters.bucketName
    | filter userIdentity.arn like /lab-app-role/ and (eventName = "ListBuckets" or eventName = "GetObject")
    | sort @timestamp desc

## C. Sensitive object read (data exfiltration)
    fields @timestamp, eventName, sourceIPAddress, requestParameters.bucketName, requestParameters.key
    | filter eventName = "GetObject"
    | sort @timestamp desc
