const REPO = process.env.THRUM_REPO ?? "vraj00222/thrum";
const RELEASES_PAGE = `https://github.com/${REPO}/releases/latest`;

/**
 * Redirects to the .dmg on the latest GitHub release. The binary never lands in
 * the repo and the button can't go stale. Cached for 5 minutes so a burst of
 * downloads doesn't spend the API's unauthenticated rate limit.
 */
export async function GET() {
  try {
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
      next: { revalidate: 300 },
    });

    if (!response.ok) return Response.redirect(RELEASES_PAGE, 302);

    const release = await response.json();
    const dmg = release.assets?.find((asset: { name: string }) =>
      asset.name.endsWith(".dmg"),
    );

    // No build published yet: send people to the releases page rather than a 404.
    return Response.redirect(dmg?.browser_download_url ?? RELEASES_PAGE, 302);
  } catch {
    return Response.redirect(RELEASES_PAGE, 302);
  }
}
