import os
import json
import logging
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException
import uvicorn
from google.cloud import secretmanager
from google.cloud import logging as cloud_logging
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from linebot import LineBotApi
from linebot.models import TextSendMessage
from linebot.exceptions import LineBotApiError

# FastAPI app initialization
app = FastAPI(title="Gmail to LINE Notification Service")

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Cloud Logging (only in production)
if os.getenv("PROJECT_ID"):
    try:
        client = cloud_logging.Client()
        client.setup_logging()
        logger.info("Cloud Logging initialized")
    except Exception as e:
        logger.warning(f"Failed to initialize Cloud Logging: {e}")


def get_secret(secret_name: str) -> str:
    """Retrieve secret from Secret Manager"""
    try:
        project_id = os.environ.get("PROJECT_ID")
        if not project_id:
            raise ValueError("PROJECT_ID environment variable not set")

        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{project_id}/secrets/{secret_name}/versions/latest"
        response = client.access_secret_version(request={"name": name})
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logger.error(f"Failed to retrieve secret {secret_name}: {e}")
        raise


def get_gmail_service(credentials_json: str):
    """Initialize Gmail API service"""
    try:
        creds_data = json.loads(credentials_json)
        credentials = Credentials.from_authorized_user_info(creds_data)
        service = build('gmail', 'v1', credentials=credentials)
        return service
    except Exception as e:
        logger.error(f"Failed to initialize Gmail service: {e}")
        raise


def get_unread_emails(service, max_results: int = 10) -> List[Dict[str, Any]]:
    """Fetch unread emails from Gmail"""
    try:
        results = service.users().messages().list(
            userId='me',
            q='is:unread',
            maxResults=max_results
        ).execute()

        messages = results.get('messages', [])

        if not messages:
            logger.info("No unread messages found")
            return []

        email_list = []
        for msg in messages:
            msg_data = service.users().messages().get(
                userId='me',
                id=msg['id'],
                format='metadata',
                metadataHeaders=['From', 'Subject', 'Date']
            ).execute()

            headers = msg_data.get('payload', {}).get('headers', [])
            email_info = {
                'id': msg['id'],
                'from': next((h['value'] for h in headers if h['name'] == 'From'), 'Unknown'),
                'subject': next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject'),
                'date': next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown'),
            }
            email_list.append(email_info)

        logger.info(f"Found {len(email_list)} unread emails")
        return email_list

    except Exception as e:
        logger.error(f"Failed to fetch unread emails: {e}")
        raise


def send_line_notification(line_token: str, emails: List[Dict[str, Any]]) -> None:
    """Send notification to LINE"""
    try:
        if not emails:
            logger.info("No emails to notify")
            return

        line_bot_api = LineBotApi(line_token)

        # Format message
        message_text = f"📧 未読メール {len(emails)}件\n\n"
        for i, email in enumerate(emails[:10], 1):  # Limit to 10 emails
            message_text += f"{i}. {email['subject']}\n"
            message_text += f"   From: {email['from']}\n\n"

        # Send to LINE (broadcast to all followers)
        line_bot_api.broadcast(TextSendMessage(text=message_text))
        logger.info(f"Successfully sent LINE notification for {len(emails)} emails")

    except LineBotApiError as e:
        logger.error(f"LINE API error: {e}")
        raise
    except Exception as e:
        logger.error(f"Failed to send LINE notification: {e}")
        raise


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}


@app.post("/")
async def trigger():
    """Main endpoint triggered by Cloud Scheduler"""
    try:
        logger.info("Processing started")

        # 1. Get secrets from Secret Manager
        secret_name_gmail = os.environ.get("SECRET_NAME_GMAIL")
        secret_name_line = os.environ.get("SECRET_NAME_LINE")

        if not secret_name_gmail or not secret_name_line:
            raise ValueError("Secret names not configured in environment variables")

        logger.info("Retrieving secrets from Secret Manager")
        gmail_creds_json = get_secret(secret_name_gmail)
        line_token = get_secret(secret_name_line)

        # 2. Initialize Gmail service
        logger.info("Initializing Gmail service")
        gmail_service = get_gmail_service(gmail_creds_json)

        # 3. Fetch unread emails
        logger.info("Fetching unread emails")
        unread_emails = get_unread_emails(gmail_service, max_results=10)

        # 4. Send LINE notification if there are unread emails
        if unread_emails:
            logger.info(f"Sending LINE notification for {len(unread_emails)} emails")
            send_line_notification(line_token, unread_emails)

            return {
                "message": "Processing completed successfully",
                "emails_found": len(unread_emails),
                "notification_sent": True
            }
        else:
            logger.info("No unread emails found, skipping notification")
            return {
                "message": "Processing completed successfully",
                "emails_found": 0,
                "notification_sent": False
            }

    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        raise HTTPException(status_code=500, detail=f"Configuration error: {str(e)}")

    except Exception as e:
        logger.error(f"Processing failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Processing failed: {str(e)}")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="debug")
