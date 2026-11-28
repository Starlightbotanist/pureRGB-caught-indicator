# pureRGB caught indicator

This fork adds a caught Poké Ball icon to wild battles. Download the BPS patch ZIP for PureBlue, PureGreen, or PureRed from [Releases](https://github.com/Starlightbotanist/pureRGB-caught-indicator/releases).

- [`master`](https://github.com/Starlightbotanist/pureRGB-caught-indicator/tree/master) mirrors [Vortyne/pureRGB](https://github.com/Vortyne/pureRGB).
- [`caught-indicator`](https://github.com/Starlightbotanist/pureRGB-caught-indicator/tree/caught-indicator) carries the fork's gameplay changes and supplies the release tags.
- `release-automation` is the default branch so GitHub can run the scheduled workflow. Open source changes against `caught-indicator`.

The [release workflow](https://github.com/Starlightbotanist/pureRGB-caught-indicator/actions/workflows/caught-indicator-release.yml) checks every 30 minutes for stable upstream releases. It fast-forwards `master` and processes one missing release at a time in publication order. The build uses the tagged RGBDS version and upstream BPS assets to produce one ZIP with three patches for the original games. A manual run previews the next release unless **publish** is selected.

If the release merge conflicts, merge that exact upstream tag into `caught-indicator`, resolve the conflicts, and push the resolution. Run the workflow with **publish** selected or wait for the next scheduled check. The failed run identifies the tag and conflicted files.
