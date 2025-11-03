#!/usr/bin/env python3
"""
Script to clear all conversations and messages from the database.
Use with caution - this deletes all conversation data!
"""

import sys
from app.database import get_session_local
# Import all models to initialize relationships properly
from app.models.user import User
from app.models.conversation import Conversation, Message
from app.models.project import Project
from app.models.backlink import BacklinkSubmission, BacklinkCampaign
from app.models.pin import PinnedItem
from sqlalchemy import text

def clear_all_conversations():
    """Delete all conversations and messages from the database"""
    SessionLocal = get_session_local()
    db = SessionLocal()
    
    try:
        # Count before deletion
        conversation_count = db.query(Conversation).count()
        message_count = db.query(Message).count()
        
        print(f"📊 Current database state:")
        print(f"  - Conversations: {conversation_count}")
        print(f"  - Messages: {message_count}")
        
        if conversation_count == 0:
            print("✅ Database is already empty!")
            return
        
        # Confirm deletion
        response = input(f"\n⚠️  Are you sure you want to delete ALL {conversation_count} conversations and {message_count} messages? (yes/no): ")
        
        if response.lower() != 'yes':
            print("❌ Deletion cancelled.")
            return
        
        # Delete all messages first (due to foreign key constraints)
        print("\n🗑️  Deleting messages...")
        db.query(Message).delete()
        
        # Delete all conversations
        print("🗑️  Deleting conversations...")
        db.query(Conversation).delete()
        
        # Commit the changes
        db.commit()
        
        print("\n✅ Successfully deleted all conversations and messages!")
        print(f"  - Deleted {conversation_count} conversations")
        print(f"  - Deleted {message_count} messages")
        
    except Exception as e:
        db.rollback()
        print(f"\n❌ Error: {e}")
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    print("🧹 Conversation Cleaner")
    print("=" * 50)
    clear_all_conversations()

