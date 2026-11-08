# Native iOS design

The Stremio visual reference is retained through a navy canvas, violet interactive tint (#7B5BF5), title artwork, and spacious poster shelves. SF Symbols and system text styles keep the app native and support Dynamic Type.

Five system tabs: Home, Discover, Library, Addons, Settings. Each owns a NavigationStack; title details push, stream selection and addon installation use sheets. The native AVKit player owns media controls and fullscreen.

Canvas is #0C0B11 in dark mode and #F7F6FB in light mode. Surface is #1A173E in dark mode and #EEECF7 in light mode. Foreground uses semantic primary/secondary colors. Grid columns adapt from 120–200 points. Poster shelf cards are 128×190 points with 12-point corners. Featured artwork uses a black readability scrim; this is content treatment, not decorative glass. General spacing is 8/14/20/24/30 points.

Screens use real loading, empty, retry, and playback failure states. No fake content or empty actions. Image failures display a neutral film symbol. Dynamic Type, native dismissal/back gestures, and readable labels take precedence over matching Windows chrome.
