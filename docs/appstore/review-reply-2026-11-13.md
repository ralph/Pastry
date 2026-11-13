# Reply to Guideline 2.1 — Information Needed (2026-11-13)

Submission `ffeaf8c8-db9e-419d-8dc5-e170654ed04c`, version 0.1.1, build 12.1.
Resolution Center thread `82ab113f-5769-3f6d-8362-de9fbf3f3ad7`.

The text below is what goes in the Resolution Center reply. The same
information is in `review-notes.txt`, which is now on the App Review
Information record, as the letter asked.

---

Thank you for the review.

Pastry is a menu-bar application. It has no window and no Dock icon, and it
does not appear in Command-Tab. Launching it puts a small scissors icon at
the right-hand end of the macOS menu bar, and nothing else happens until that
icon is clicked or the keyboard shortcut is used. We suspect that is why the
app looked incomplete, so we have rewritten the App Review Information notes
to begin with exactly that, and the answers below start there too.

One detail that may have added to the confusion: the App Store icon is a
cupcake, while the menu-bar icon is a pair of scissors. A menu-bar icon has
to be a flat monochrome template image, so it cannot be the app icon.

**1. Screen recording**

Attached. It is Pastry 0.1.1 running on macOS 26. It begins with launching
the app and shows the scissors icon appearing in the menu bar, three pieces
of text being copied in TextEdit, the menu being opened and filtered with its
search field, and a clipping being pasted — both by choosing it from the menu
and by holding Shift-Command-V and releasing.

On the specific items listed: Pastry has no account registration, login or
account deletion flows, because it has no accounts of any kind. It has no
user-generated content that reaches another person, so there is nothing to
report or block. It has no paid content, no in-app purchases and no
subscriptions; the app is free in full.

**2. Purpose and target audience**

Pastry remembers the text you copy, so you can paste something you copied
five minutes ago without going back to find it again. macOS keeps only the
most recent clipboard item; anything you copy replaces what was there, and it
is gone.

It is for people who copy and paste all day — developers, writers, support
staff, anyone moving text between applications. The value is that the
material you already copied is still reachable, by keyboard, without leaving
what you are doing.

**3. Setting up and accessing the main features**

No setup, no credentials and no sample files are needed. There is nothing to
sign in to.

1. Launch Pastry. Look for the scissors icon in the menu bar.
2. In any application, copy two or three different pieces of text with
   Command-C.
3. Click the scissors icon. The menu lists what you copied, newest first,
   with a search field at the top that filters as you type.
4. Choose one. It is pasted into the application you were last typing in.
5. Or hold Shift-Command-V and tap V repeatedly. A panel appears in the
   middle of the screen showing one clipping at a time, walking back through
   the history. Release the modifier keys and the clipping you stopped on is
   pasted.

Settings, reachable from the same menu, let you change the keyboard shortcut,
how many clippings are kept, how many are listed, and whether the app starts
at login.

The first time you choose a clipping, macOS asks for Accessibility
permission. Pastry needs it to paste into the frontmost application on your
behalf, and that is the only thing it uses it for. Declining is not a dead
end: the clipping still goes onto the system clipboard and you press
Command-V yourself.

**4. External services, tools and platforms**

None. Pastry contains no network code at all — no HTTP client, no sockets, no
analytics, no crash reporting, no authentication service, no payment
processor, no AI or data provider, and no third-party SDKs. It is built
entirely on Apple's own frameworks (AppKit, SwiftUI, Foundation).

The clipboard history is stored in a file inside the app's own container and
never leaves the Mac. Clippings that an application marks as concealed —
password fields, mostly — are skipped and never stored at all.

The app is open source; the whole of it can be read at
https://github.com/ralph/Pastry

**5. Regional differences**

There are none. The app behaves identically everywhere, is English-only, and
has no regional content, features or pricing. It is free in all territories.

**6. Regulated industry or protected third-party material**

Neither applies. Pastry is a clipboard utility. It operates in no regulated
industry, and contains no third-party or protected material — the code, the
icon and the copy are all our own, under the MIT licence.
