# Database Schema for Applicant Showcase App

## Collection: `users`

Stores journalist/editor information. Each document corresponds to an authenticated Firebase user.

| Field | Type | Required | Description | Storage Path Pattern |
|-------|------|----------|-------------|----------------------|
| id | string | Yes | Firebase Auth UID (matches document ID) | - |
| email | string | Yes | User's email address | - |
| name | string | Yes | Full name of journalist | - |
| profilePictureURL | string | No | Profile picture in Cloud Storage | `media/users/{userId}/profile.{ext}` |
| role | string | Yes | `journalist`, `editor`, or `admin` | - |
| createdAt | timestamp | Yes | When user registered | - |
| updatedAt | timestamp | No | Last profile update | - |

**Notes:**
- Document ID must equal the Firebase Authentication UID
- `profilePictureURL` is optional; if present, points to Storage

---

## Collection: `articles`

Stores news articles uploaded by journalists.

| Field | Type | Required | Description | Storage Path Pattern |
|-------|------|----------|-------------|----------------------|
| id | string | Yes | Auto-generated Firestore document ID | - |
| title | string | Yes | Article title (max 200 chars) | - |
| content | string | Yes | Full article content (markdown/HTML supported) | - |
| authorId | string | Yes | **Foreign key to `users.id`** (journalist who wrote) | - |
| thumbnailURL | string | Yes | Main article image in Cloud Storage | `media/articles/{articleId}/thumbnail.{ext}` |
| excerpt | string | No | Short summary (max 150 chars) | - |
| tags | array | No | Categories: `["technology", "news", "lifestyle"]` | - |
| published | boolean | Yes | `true` = public, `false` = draft | - |
| createdAt | timestamp | Yes | When article was created | - |
| updatedAt | timestamp | Yes | Last edit timestamp | - |

**Notes:**
- `authorId` must reference an existing document in `users` collection
- `thumbnailURL` is **REQUIRED** per project specifications
- Articles are only publicly readable when `published` is `true`
- `thumbnailURL` follows exact pattern: `media/articles/{articleId}/{filename}`

---

## Firebase Cloud Storage Structure
