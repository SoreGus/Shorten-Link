# URL Shortener — Exercise

This exercise aims at creating a small application that allows you to shorten links and display a
history of the recently shortened links to your favorite websites.


---

## Screen

The app contain:

- **1 text input** where the user can type a website URL to shorten
- **1 button** that triggers the action of sending this link to the backend service
- **1 list** displaying the recently shortened links/aliases (history)

---

## API

### Base URL

```
https://url-shortener-server.onrender.com/api/alias
```

---

### 1) Shorten URL

**Request**

- Path: `/api/alias`
- Method: `POST`
- Body (JSON):
  ```json
  {
    "url": "<the url>"
  }
  ```

**Response**

- Status: `201 Created` on success
- Body:
  ```json
  {
    "alias": "<url alias>",
    "_links": {
      "self": "<original url>",
      "short": "<short url>"
    }
  }
  ```

---

### 2) Read shortened URL (expand alias)

**Request**

- Path: `/api/alias/:id`
- Method: `GET`

**Response (Success)**

- Status: `200 OK`
- Body:
  ```json
  {
    "url": "<the original url>"
  }
  ```

**Response (Not found)**

- Status: `404 Not Found`

---
