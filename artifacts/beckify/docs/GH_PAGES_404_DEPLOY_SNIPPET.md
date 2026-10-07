# GitHub Pages deploy snippet (Search Console 404 fix)

OAuth tokens used by agents cannot update `.github/workflows/deploy.yml`
(needs the `workflow` scope). After merging the rest of this fix, replace the
deploy step named **Add CNAME and SPA fallback** with:

```yaml
      - name: Add CNAME and verify real 404 page
        run: bash artifacts/beckify/scripts/finalize-gh-pages.sh
```

Do **not** keep:

```yaml
cp artifacts/beckify/dist/public/index.html artifacts/beckify/dist/public/404.html
```

That line published the homepage as the 404 body and caused soft-404s in
Search Console.
