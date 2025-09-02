# 📚 Documentation Setup Guide

This guide explains how to set up live documentation hosting for Monstra using GitHub Pages.

## 🚀 Quick Setup (Recommended)

### 1. Enable GitHub Pages
1. Go to your repository: `https://github.com/yangchenlarkin/Monstra`
2. Click **Settings** tab
3. Scroll down to **Pages** section
4. Under **Source**, select **GitHub Actions**
5. Click **Save**

### 2. Trigger Documentation Build
The documentation will automatically build and deploy when you push to the `main` branch. To trigger it manually:

1. Go to **Actions** tab in your repository
2. Click **Documentation** workflow
3. Click **Run workflow**
4. Select `main` branch and click **Run workflow**

### 3. Update README Links
Once GitHub Pages is live, update the README.md documentation links:

```markdown
## 📚 Documentation

- 📖 **[Getting Started Guide](https://yangchenlarkin.github.io/Monstra/getting-started)** - Installation and basic usage
- 🏗️ **[API Reference](https://yangchenlarkin.github.io/Monstra/documentation/monstra)** - Complete API documentation
- 📋 **[Caching Strategies](https://yangchenlarkin.github.io/Monstra/caching-strategies)** - Advanced usage patterns
```

## 🔧 Manual Setup (Alternative)

If you prefer to set up Pages manually:

1. Go to repository **Settings** → **Pages**
2. Under **Source**, select **Deploy from a branch**
3. Select `gh-pages` branch (will be created by the workflow)
4. The workflow will automatically create and update this branch

## 📋 What Happens Next

### Automatic Process
1. **Push to main branch** → Documentation workflow triggers
2. **DocC builds documentation** → Generates static HTML files
3. **GitHub Pages deploys** → Documentation goes live
4. **URLs become available** → `https://yangchenlarkin.github.io/Monstra/`

### Expected URLs
- **Main Documentation**: `https://yangchenlarkin.github.io/Monstra/`
- **API Reference**: `https://yangchenlarkin.github.io/Monstra/documentation/monstra`
- **Getting Started**: `https://yangchenlarkin.github.io/Monstra/getting-started`
- **Caching Strategies**: `https://yangchenlarkin.github.io/Monstra/caching-strategies`

## 🐛 Troubleshooting

### Documentation Not Building
1. Check **Actions** tab for workflow status
2. Look for errors in the **Documentation** workflow
3. Ensure DocC is available in the macOS runner

### Pages Not Deploying
1. Verify GitHub Pages is enabled in repository settings
2. Check that the workflow completed successfully
3. Wait 2-3 minutes for deployment to complete

### Links Still 404
1. Wait for the first deployment to complete (can take 2-3 minutes)
2. Clear your browser cache
3. Check the exact URL format

## 📊 Status Check

You can verify the setup by:

1. **Workflow Status**: Check Actions tab → Documentation workflow
2. **Pages Status**: Settings → Pages section
3. **Live Documentation**: Visit `https://yangchenlarkin.github.io/Monstra/`

## 🎯 Next Steps

Once documentation is live:
1. Update any external links (social media, blog posts, etc.)
2. Add documentation badges to README
3. Share the documentation links with the community

## 📞 Support

If you encounter issues:
1. Check the [GitHub Pages documentation](https://docs.github.com/en/pages)
2. Review the workflow logs in the Actions tab
3. Ensure your repository is public (Pages works better with public repos)

---

**Note**: This setup uses GitHub Actions to automatically build and deploy your DocC documentation, ensuring it stays up-to-date with your code changes.
