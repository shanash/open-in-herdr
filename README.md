# Open in Herdr

A Finder toolbar button that opens the folder you are looking at in
[Herdr](https://herdr.dev), as a new tab in Herdr's current space.

- Starts Herdr first if it is not running.
- If Herdr has no space to add a tab to, it opens the folder as a new space.
- With no Finder window open, it opens the Desktop.

## Install

Requires macOS and Herdr.

```sh
curl -fsSL https://raw.githubusercontent.com/<owner>/open-in-herdr/main/install.sh | bash
```

or, from a clone of this repository:

```sh
./install.sh
```

This puts `Open in Herdr.app` in `~/Applications` (set `INSTALL_DIR` to use
another folder). Then:

1. Hold Command (⌘) and drag the app onto a Finder window's toolbar.
2. Click it once and allow it to control Finder when macOS asks.

To hide the button's text label, right-click the toolbar and choose
**Icon Only** (this applies to every toolbar item; Finder cannot hide one
item's label).

Running the installer again replaces an earlier install.

## How it works

Herdr does not accept folders through `open -a`, so the button calls Herdr's
command line: `Herdr do tab.new --folder <path>`.

The installer builds the app on your Mac with `osacompile` instead of shipping a
prebuilt app. A locally built app is not quarantined, so Gatekeeper does not
show an "unidentified developer" warning, and no Apple Developer signing is
needed. The button's icon is copied from your installed Herdr.app; this
repository does not redistribute Herdr's artwork.

## Uninstall

```sh
./uninstall.sh
```

Then hold Command (⌘) and drag the button off the Finder toolbar.
