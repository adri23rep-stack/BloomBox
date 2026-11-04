# BloomBox 2.0 remote news

The widgets landing page can show a remote news feed **without publishing a new IPA**.

## Editing announcements

Edit [news.json](./news.json) on GitHub and commit it to this branch. The Home widgets page loads it from:

`https://raw.githubusercontent.com/adri23rep-stack/BloomBox/feature/bloombox-2-ui-foundation-20261031/remote/news.json`

Once BloomBox 2.0 is merged into `main`, point the in-app **Novedades > link icon** to:

`https://raw.githubusercontent.com/adri23rep-stack/BloomBox/main/remote/news.json`

You can also host the feed at any other public HTTPS JSON URL and configure it from the app.

## Format

```json
{
  "posts": [
    {
      "id": "announcement-001",
      "title": "What is new",
      "text": "Write an announcement here, including Unicode and emoji.",
      "media": "https://example.com/large-image.png"
    },
    {
      "id": "animated-002",
      "title": "GIF announcement",
      "text": "Optional animation",
      "media": "https://example.com/animation.gif"
    }
  ]
}
```

- `media` may be omitted, blank, or a HTTPS URL to PNG/JPG/WebP/GIF.
- Post IDs must be unique. Maximum **12** displayed items; feed JSON limited to **256 KB** and downloaded GIFs to **10 MB** each.
- Text is rendered as text; no embedded HTML or scripts run.
- Tap **Refresh** in the Home widgets page after changing the file. Data cached on GitHub's CDN may be briefly stale.
- Personal photos/GIFs used in Home widgets are stored locally under Application Support, not in the remote feed. Removing a widget deletes its unused imported media.
- Do not place private data in a public feed. Remote news media sources receive network requests from users' phones.

## UI behavior

- Page 0 (widget/news landing) hides the floating page bar and Dock; horizontal swipe still navigates.
- Home pages use a shared 4×6 grid. Context-menu sizes are 1×1, 2×2, 4×2, and 4×4. The layout attempts to relocate icons rather than discard them.
- Existing page widgets are migrated once to the new grid; saved guest app information and data containers are not touched.
- Ordinary UI notifications are deferred by 10 seconds after launching, while security and installation prompts remain immediate.
