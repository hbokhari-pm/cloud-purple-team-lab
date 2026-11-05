# Attack Log — Cloud Purple Team Lab

> All actions performed against my own lab resources in my own AWS account.
> Credentials shown in screenshots are from a disposable lab role and are
> destroyed at the end of each session. **Do not commit real credential values.**

## Step 1 — Web exploitation: SQL injection login bypass
- **Target:** Juice Shop login form
- **Payload:** `' OR 1=1--` in the email field
- **Result:** logged in as the first user (admin) without a password
- **MITRE ATT&CK:** T1190 — Exploit Public-Facing Application

## Step 2 — Credential theft via IMDSv1
- **Context:** assuming SSRF/RCE foothold on the instance
- **Action:** queried 169.254.169.254 for the instance role's credentials
- **Result:** retrieved temporary AccessKeyId / SecretAccessKey / Token
- **MITRE ATT&CK:** T1552.005 — Unsecured Credentials: Cloud Instance Metadata API

## Step 3 — Use stolen credentials from attacker machine
- **Action:** configured the stolen creds locally and called sts get-caller-identity
- **Result:** confirmed I was acting as lab-app-role from outside AWS
- **MITRE ATT&CK:** T1078.004 — Valid Accounts: Cloud Accounts

## Step 4 — Exfiltrate customer data from S3
- **Action:** listed and downloaded the S3 bucket with the stolen creds
- **Result:** pulled customers.csv (mock PII) out of the account
- **MITRE ATT&CK:** T1530 — Data from Cloud Storage Object
````
````

Now the attack.

---

### Step 1: Web exploitation (SQL injection)

In your browser on the Juice Shop site:
1. Click the menu (top-left ☰) → **Account** → **Login**.
2. In the **Email** field, type exactly: `' OR 1=1--`
3. In the **Password** field, type anything, like `x`.
4. Click **Log in**.

You should be logged in as the admin account without knowing the password. That's a classic SQL injection authentication bypass. Take a screenshot.

*(Burp Suite isn't required for this one. If you want to practice with it, you can capture and replay the same login request, but the browser method is enough.)*

Tell me when you're logged in, and I'll give you Step 2 (stealing the credentials from the metadata service). I'm splitting the steps so you can screenshot each one for the log.