# Portrait crown and resting indicator placement

## User choice

Use the target crown as the reference, move it a little farther inward, mirror the player crown, and move the rested Zs to the opposite side of the main player portrait if supported. Keep the earlier requested slight rightward adjustment for classic party crowns.

## Design

- Interpret inward as toward the name/health bars: left on target/focus, right on player/classic party. Use two additional portrait UI units from target/focus's existing crown position.
- Use portrait-relative crown corners with one mirrored clearance: Player TOPLEFT to portrait TOPRIGHT at (5, 11), Target/Focus TOPRIGHT to portrait TOPLEFT at (-5, 11), with effective-scale conversion.
- Classic pooled party crowns retain their BOTTOM-to-overlay-TOP native attachment and vertical coordinate, shifted two UI units right. They keep a separate profile because their native geometry is smaller.
- Reflect the existing rested position from +48 to -48 portrait units, retaining native height, original texture, animation, visibility and ownership. This mirrors placement; the native FlipBook has no established persistent artwork-mirroring control. Supported positional mirroring means the user's right-of-crown alternative is not needed.

## Approaches considered

The earlier proposal raised Zs above the crown while keeping them on the right. The user instead chose opposite-side placement, which separates the two indicators without depending on leader visibility. Native-relative crown nudges preserve differing player/target geometry; shared portrait-relative crown geometry resolves that mismatch.

## Constraints and evidence

Change only indicator geometry. Apply writes only when permissions positively allow them; party writes also require non-raid mode and current pooled membership. Preserve one hook per physical texture, accepted-write receipts, refusal retries, and other addons' foreign anchors. Native icons, animation, timers, saved layouts and all .349 visual treatment retain their existing behavior. Offline tests establish geometry/lifecycle behavior; the final in-game optical fit remains a user check.

## .351 correction after the live screenshots

The .350 optical result was rejected: target/focus crowns crowd their secondary circles and the left-side Zs look detached. Keep the player crown at (5, 11); use (-7, 11) for target/focus as a small screenshot-based optical correction. Equal mirrored anchors are not evidence of equal visible clearance. The inspected .248 and .252 bjarkiPortraits sources share geometry, and no exact live renderer cause was established.

Use the user's already-authorized right-of-crown fallback: original RestTexture CENTER to native player LeaderIcon RIGHT, X = actual Z width / 2 + 2 portrait units converted to Z scale, Y = 0. The native crown supplies the attachment even while hidden. Preserve the original animation/artwork and recalibrate an owned anchor on existing safe scale/layout events. No cross-addon secondary-frame enumeration or new geometry API is needed. The former positional mirror was possible but visually unsuitable; it is superseded.

## .352 user decision: remove Zs completely

The user rejected the animated Z appearance after .351 and explicitly requested removal. Retire placement calculations and hide only the original RestTexture, observing Show/SetShown so native refreshes cannot restore it. Keep native resting state and the parent animation owner separate. Apply only with positive safe, out-of-combat permission and current physical-region identity. Existing crown placements remain the .351 profiles. No new options, polling, assets or cross-addon dependency.

## .353 classic-party visual follow-up

The user's party-frame screenshot shows the crown touching/crowding the smaller secondary portrait. Increase only the classic-party native horizontal nudge from +2 to +4 UI units, preserving native height and the existing membership/permission/ownership checks. This adds clearance toward the name/health bars and keeps the .352 rested-Z removal. The adjustment is calibrated from the screenshot, not a claim of live pixel verification.

## .354 remove classic-party faction badges

Build from the user-approved .353 crown spacing. The latest request removes the small faction shields from classic-party portraits. Hide only PartyMemberOverlay.PVPIcon, which native UpdatePvPStatus reuses for Alliance, Horde and FFA. Reuse current pool discovery and events, prepare Show/SetShown hooks outside combat, and let installed observers apply guarded cosmetic Hide during combat. Recheck current ownership and non-raid/public/nonforbidden permission on every callback. Avoid persistent alpha state, which would require extra restoration on recycled icons. Keep actual PvP state, atlas selection and other icons native.
