# DocuKit — Copy Deck (English)

Source of truth for `lib/l10n/app_en.arb`. Keys are camelCase in ARB; they're shown here in snake_case for readability. Placeholders use `{name}`. Voice: plain words, second person, no exclamation marks, no "Oops". Never promise outcomes ("up to 90% smaller").

## 1. Global
| Key | Text |
|---|---|
| app_name | DocuKit |
| privacy_promise | Files never leave your phone |
| action_continue / cancel / done / retry / remove / replace / details / rename / save / share / open_with / leave / stay / discard / keep_anyway / try_again | Continue / Cancel / Done / Try again / Remove / Replace / Details / Rename / Save / Share / Open with… / Leave / Stay / Discard / Keep anyway / Try again |
| original_unchanged | Your original file was not changed. |
| choose_another | Choose another file |
| back_to_tool | Back to tool |

## 2. Home, search, onboarding
| Key | Text |
|---|---|
| home_search_placeholder | Search tools — "make photo smaller" |
| home_section_image / pdf / recent | IMAGE TOOLS / PDF TOOLS / RECENT |
| home_see_all | See all |
| home_continue | Continue: {toolName} |
| home_recent_empty | Your finished files will show up here. |
| home_job_running | Processing… Tap to view |
| search_hint_empty | Try: compress, combine PDF, passport photo, rotate page |
| search_no_results | No tool matches "{query}". |
| search_matches | Matches "{phrase}" |
| onb_title | Document tools that stay on your phone |
| onb_b1 / b2 / b3 | Compress and resize photos / Make and edit PDFs / No account. No uploads. |
| onb_cta | Get started |

### 2.1 Home v2 and quick actions (v2.1 — UI_REFRESH §2)
| Key | Text |
|---|---|
| home_greeting_morning / afternoon / evening | Good morning / Good afternoon / Good evening |
| home_saved_so_far | You've saved {size} so far |
| home_quick_actions | Quick actions |
| qa_passport / qa_under_100kb / qa_signature / qa_photos_to_pdf / qa_merge_pdfs / qa_email_pdf | Passport photo / Under 100 KB / Signature / Photos to PDF / Merge PDFs / Email-size PDF |
| home_help_tooltip | Take the tour |

### 2.2 Home tour (v2.1 — TOUR.md §5)
| Key | Text |
|---|---|
| tour_intro_title / body | Quick tour / See what DocuKit can do in about 30 seconds. |
| tour_start / skip / next / back / done / try | Start tour / Skip / Next / Back / Done / Try it |
| tour_progress | Step {n} of {total} |
| tour_search_title / body | Search in plain words / Type what you need, like "make photo smaller" or "join PDFs". |
| tour_image_compress_title / body / example | Image Compressor / Make photos smaller. Pick a quality, or set a limit like "under 100 KB". / Great for job and exam portals with upload limits. |
| tour_image_resize_title / body / example | Image Resizer / Set an exact size in pixels or percent, or use a preset. / Passport photo 413×531 or a signature at 140×60. |
| tour_image_to_pdf_title / body / example | Images to PDF / Turn several photos into one PDF, in the order you choose. / Notes, receipts or certificates in one file. |
| tour_pdf_merge_title / body / example | Merge PDFs / Combine several PDFs into one. Drag to set the order. / Put a cover letter and CV together. |
| tour_pdf_organize_title / body / example | Organize Pages / Reorder, rotate or delete pages, then save a new copy. / Fix a sideways scan or remove a blank page. |
| tour_pdf_compress_title / body / example | Reduce PDF Size / Make a PDF smaller for email, with clear choices about quality. / Get under a 10 MB email limit. |
| tour_recent_title / body | Your recent files / Finished files appear here for {period}, so you can save or share them again. |
| tour_nav_title / body | History and settings / See everything you've made, and set your favourite defaults. |
| tour_done_title / body | You're all set / Your files never leave your phone, and originals are never changed. Tap any tool to start. |
| tour_whats_new | New in DocuKit |
| set_take_tour | Take the tour |
| a11y_tour_step | Step {n} of {total}. {title}. {body} |

## 3. Tools

| Key | Text |
|---|---|
| tool_image_compress_title / subtitle | Image Compressor / Make photos smaller |
| tool_image_resize_title / subtitle | Image Resizer / Set an exact size |
| tool_image_to_pdf_title / subtitle | Images to PDF / Turn photos into one PDF |
| tool_pdf_merge_title / subtitle | Merge PDFs / Combine files into one |
| tool_pdf_organize_title / subtitle | Organize Pages / Reorder, rotate or delete |
| tool_pdf_compress_title / subtitle | Reduce PDF Size / Make a PDF smaller |
| pick_images / pick_image / pick_pdfs / pick_pdf | Choose images / Choose image / Choose PDFs / Choose PDF |
| pick_formats_images | JPG, PNG, WebP or HEIC · up to 100 MB |
| pick_formats_pdf | PDF · up to 500 MB |
| inputs_header | FILES ({count}) |
| inputs_add | Add |
| inputs_manage_all | Manage all files |
| inputs_truncated | Only the first {max} files were added. |
| large_file_hint | Large file — this may take a while. |
| cmp_mode_quality / target | Quality / Target size |
| cmp_quality_low / high | Smaller file / Sharper |
| cmp_target_label | Keep under |
| cmp_target_already_smaller | This image is already under {size}. |
| cmp_more_options | More options |
| cmp_format_same | Same as original |
| cmp_max_size | Max size |
| cmp_strip_meta | Remove location and camera info |
| cmp_png_warning | PNG doesn't use quality. Choose JPEG or WebP for smaller files. |
| cmp_switch_jpeg | Switch to JPEG |
| warn_alpha_lost | Transparent areas will become white. |
| cmp_target_uses_jpeg | Target size uses JPEG. |
| cmp_run | Compress image |
| res_mode_pixels / percent / preset | Pixels / Percent / Preset |
| res_width / height | Width / Height |
| res_lock_on / off (a11y) | Aspect ratio locked / Aspect ratio unlocked |
| res_original | Original {w} × {h} |
| res_result_line | Result: {w} × {h} px |
| res_shape_header | WHEN THE SHAPE CHANGES |
| res_fit_stretch / contain / cover | Stretch / Fit with border / Crop to fill |
| res_upscale_warning | Enlarging can make the image blurry. |
| res_err_range | Enter a number from 1 to 12000. |
| res_err_megapixels | That would be over 100 megapixels. Choose a smaller size. |
| res_save_preset | Save as preset |
| res_preset_passport / signature / square / story / hd / fullhd | Passport photo (35×45 mm) / Signature / Square post / Story / HD / Full HD |
| res_run | Resize image |
| i2p_header | IMAGES ({count}) |
| i2p_empty_hint | Up to 100 images. Pages follow this order. |
| i2p_page_size / orientation / fit / margins / quality | Page size / Orientation / Image fit / Margins / Image quality |
| i2p_size_image | Same as image |
| i2p_orient_auto | Auto |
| i2p_fit_fit / fill | Fit whole image / Fill page |
| i2p_margin_none / small / large | None / Small / Large |
| i2p_q_original / high / compact | Original / High / Compact |
| i2p_run | Create PDF ({count, plural, =1{1 page} other{# pages}}) |
| i2p_run_empty | Create PDF *(button label before any image is chosen)* |
| mrg_total | {files} PDFs · {pages} pages total |
| mrg_drag_hint | Drag to change the order. Files are merged top to bottom. |
| mrg_need_two | Add at least 2 PDFs |
| mrg_remove_invalid | Remove {count, plural, =1{1 file} other{# files}} that can't be merged |
| mrg_run | Merge {count} PDFs |
| mrg_info_sheet | Pages are copied exactly. Bookmarks and form fields may not be kept. |
| org_status | {pages, plural, =1{1 page} other{# pages}} · {selected} selected |
| org_rotate_left / right / delete / move | Left / Right / Delete / Move |
| org_move_to | Move selected pages to |
| org_move_start / end / after | Start / End / After page |
| org_min_one_page | A PDF needs at least one page. |
| org_deleted_undo | Page deleted |
| org_page_moved_from (a11y) | Page {pos}, originally page {orig} |
| org_run | Save as new PDF |
| red_analysis | {pages} pages · {images} images · {kind} |
| red_kind_image / text | Image-heavy / Mostly text |
| red_basic_t / d | Basic / Clean up the file. No quality loss. Usually a small reduction. |
| red_balanced_t / d | Balanced / Shrinks photos inside the PDF. Text stays sharp and selectable. |
| red_strong_t / d | Strong / Turns every page into an image. Smallest file. Text can't be selected or searched. |
| red_recommended | Recommended |
| red_note | How much a PDF shrinks depends on what's inside it. Text-only PDFs may not get smaller. |
| red_balanced_warning | Photos inside the PDF may look slightly softer. |
| strong_confirm_title | Use Strong reduction? |
| strong_confirm_body | Text will no longer be selectable or searchable, and links will stop working. Your original stays as it is. |
| strong_confirm_ok | Use Strong |
| red_run | Reduce size |

## 4. Job, result, errors
| Key | Text |
|---|---|
| step_preparing / reading / compressing / resizing / building_pdf / merging / saving_pages / optimizing / checking | Getting ready… / Reading files… / Compressing image… / Resizing image… / Building PDF… / Merging PDFs… / Saving pages… / Reducing size… / Checking the result… |
| progress_count | {done} of {total} {unit} |
| keep_open | Keep DocuKit open until this finishes. |
| cancel_confirm_title / body / keep / yes | Cancel this job? / Nothing will be saved. / Keep going / Cancel job |
| cancelled_snack | Cancelled. Nothing was saved. |
| busy_snack | Finish or cancel the current job first. |
| result_done | Done |
| result_before / after / change | Before / After / Change |
| result_smaller | {percent}% smaller |
| result_larger | {percent}% larger |
| result_not_smaller_img | Couldn't make this image smaller. Try a lower quality or a smaller max size. |
| result_not_smaller_pdf | This PDF is already well optimised. The result is not smaller. |
| result_target_missed | Closest we could get: {actual} (target {target}). Try a smaller max size. |
| result_retention | Kept in Recent for {period} |
| result_edit_options | Edit options |
| save_to_photos / save_to_files | Save to Photos / Save to Files… |
| saved_snack / saved_snack_named | Saved / Saved as {name} |
| save_failed | Couldn't save the file. Try another location. |
| photos_denied | DocuKit can't add to Photos. Allow it in Settings. |
| open_settings | Open Settings |
| open_with_none | No app on this device can open this file. |

### Error table (`err_<code>_title` / `_body` / actions)
| Code | Title | Body | Primary / Secondary |
|---|---|---|---|
| unsupportedFormat | This file type isn't supported | DocuKit works with JPG, PNG, WebP and HEIC images, and PDF files. | Choose another file / Back to tool |
| invalidInput | Check your settings | {detail} | Back to tool |
| encryptedDocument | This PDF is password-protected | DocuKit can't open protected files yet. Remove the password in the app that created it, then try again. | Choose another file / Back to tool |
| corruptFile | This file looks damaged | It couldn't be read. Try opening it in another app, or choose a different copy. | Choose another file / Back to tool |
| fileTooLarge | This file is too large | The limit is {limit}. Try a smaller file. | Choose another file |
| tooManyFiles | Too many files | You can add up to {max} at a time. | Back to tool |
| notEnoughFiles | Add more files | This tool needs at least {min}. | Back to tool |
| insufficientStorage | Not enough free space | About {needed} is needed. Free up some space on your phone and try again. | Try again / Back to tool |
| permissionLost | Can't read this file anymore | Please choose the file again. | Choose another file |
| processingFailed | Something went wrong | The job didn't finish. Your files are safe. | Try again / Back to tool |
| outOfMemory | This file is too big for your phone to process | Try a smaller file, or a lower max size. | Back to tool |
| outputValidationFailed | The result didn't pass our checks | We didn't keep it, to avoid giving you a broken file. Please try again. | Try again / Back to tool |
| saveFailed | Couldn't save the file | Try another location. | Try again |
| interrupted | This job was interrupted | DocuKit was closed before it finished. | Try again |
| ocrModelUnavailable *(1.3)* | Text recognition isn't ready | The {language} model couldn't be downloaded. Connect to the internet once and try again, or choose Latin. (§8.3) | Back to tool |

## 5. History, settings, privacy
| Key | Text |
|---|---|
| hist_title | Recent activity |
| hist_filter_all / images / pdfs / failed | All / Images / PDFs / Failed |
| hist_today / yesterday | Today / Yesterday |
| hist_unavailable | File no longer available |
| hist_empty | Nothing here yet. Files you create appear here for {period}. |
| hist_removed_undo | Removed from history |
| hist_clear_title | Clear history? |
| hist_clear_body | This clears the list. Files you saved elsewhere are not affected. |
| hist_clear_also_files | Also delete app copies of results |
| hist_clear_ok | Clear |
| det_title / status / tool / inputs / output / settings / saved / kept_until | Details / Status / Tool / Inputs / Output / Settings / Saved / Kept until |
| det_not_saved | Not saved to your device yet |
| det_run_again | Run again with these settings |
| det_delete_copy / remove_entry | Delete app copy / Remove from history |
| set_title | Settings |
| set_theme / system / light / dark | Theme / System / Light / Dark |
| set_keep_results / h24 / d7 / d30 / forever | Keep results for / 24 hours / 7 days / 30 days / Until I delete |
| set_storage_used | Storage used |
| set_storage_clear_title / body | Delete app copies of results? / History stays. Files you saved elsewhere are not affected. |
| set_confirm_delete | Confirm before deleting |
| set_feedback | Send feedback |
| set_version | Version {version} ({build}) |
| priv_title | Privacy & about |
| priv_local_h / p | Your files stay on your phone / Everything DocuKit does to your files happens on this device. Your files are never uploaded. *(v2.1 update, ADS.md §10)* |
| priv_account_h / p | No account / You don't need to sign up, and DocuKit doesn't know who you are. |
| ~~priv_tracking_h / p~~ | **Removed in v2.1** (ADS.md §10): the "no ads / no internet permission" claim is no longer true. Replaced by `priv_ads_h / p` below. |
| priv_ads_h / p | About ads / DocuKit shows ads from Google AdMob to stay free. Ads never see your files, file names or results. Google may use device information to show and measure ads. You can change your ad choices in Settings, or remove ads with a one-time purchase. |
| priv_access_h | What DocuKit can access |
| priv_access_photos | Only the photos you pick |
| priv_access_files | Only the files you pick |
| priv_access_photos_add | Adding to Photos, only when you tap Save to Photos |
| priv_stored_h / p | What's stored / A list of recent jobs, and copies of results for {period}. Both stay on this device and you can clear them in Settings. |
| priv_protected_h / p | Password-protected files / DocuKit doesn't open or unlock protected PDFs. |
| priv_licenses / policy | Open-source licences / Privacy policy |
| a11y_size_words | {value} {unit, select, B{bytes} KB{kilobytes} MB{megabytes} GB{gigabytes} other{}} |

### 5.1 Ads and Remove ads (v2.1 — ADS.md §10)
| Key | Text |
|---|---|
| ad_badge | Ad |
| ad_sponsored | Sponsored |
| set_remove_ads | Remove ads |
| set_remove_ads_sub | One-time purchase |
| set_ad_choices | Privacy & ad choices |
| rem_title | Remove ads |
| rem_body | Enjoying DocuKit? Remove ads once and support development. |
| rem_point1 / 2 / 3 | No ads, ever / Works on this device and future installs with the same store account / Your files stay on your phone, as always |
| rem_buy | Buy for {price} |
| rem_restore | Restore purchase |
| rem_thanks | Thanks for your support. Ads are gone. |
| rem_failed | The purchase didn't go through. You haven't been charged. |
| rew_offer | Watch a short ad: no ads for 24 hours |
| rew_offer_short | No ads for 24 hours? Watch a short ad |
| rew_granted | Done. No ads until {time} tomorrow. |
| rew_not_earned | The ad was closed early, so ads are still on. |
| rew_limit | You've used today's ad-free passes. Try again tomorrow. |
| ads_free_until | Ad-free until {time} |

> **v2.1 (done in T7.11):** `privPolicyBody1…5` were rewritten per ADS.md §9:
> 1. DocuKit has no account system and never uploads your files. Your files, file names and results stay on your device and are never sent to us or to anyone else.
> 2. *(unchanged: local processing and retention)*
> 3. *(unchanged: picker-only access)*
> 4. Ads: DocuKit shows ads from Google AdMob to stay free. To show and measure ads and to prevent fraud, Google's ads SDK collects device information such as the advertising ID, approximate location from the IP address, and how you interact with ads. It never receives your files, file names or results. Where the law requires it, DocuKit asks for your consent first, and you can change your choice in Settings → Privacy & ad choices. You can remove ads with a one-time purchase. Google's privacy policy: policies.google.com/privacy
> 5. Purchases are handled by Google Play or the App Store; we never receive your payment details. Google Play and Apple may provide anonymous crash statistics if you've allowed this in your device settings. The app isn't directed at children under 13.

### 5.2 Processing tips (v2.1 — UI_REFRESH §5)
Shown one at a time under the progress text, rotating every 5 s (static with reduce-motion). Only `tip_1` is given in UI_REFRESH; **`tip_2…tip_8` are drafts — please review before T7.3.**

| Key | Text |
|---|---|
| tip_1 | Tip: Use Target size to hit upload limits exactly. |
| tip_2 *(draft)* | Tip: The Passport photo preset gives you exactly 413 × 531 pixels. |
| tip_3 *(draft)* | Tip: Turn on "Remove location and camera info" before sharing photos. |
| tip_4 *(draft)* | Tip: Balanced shrinks photos inside a PDF and keeps the text sharp. |
| tip_5 *(draft)* | Tip: In Organize Pages, double-tap a page to see it full screen. |
| tip_6 *(draft)* | Tip: Your original file is never changed. DocuKit always makes a copy. |
| tip_7 *(draft)* | Tip: Finished files stay in Recent, so you can save or share them again. |
| tip_8 *(draft)* | Tip: Search understands plain words, like "join PDFs". |

### 5.3 Result screen (v2.1 — UI_REFRESH §6, added in T7.3)

| Key (ARB) | Text |
|---|---|
| resultDoneImage / resultDonePdf | Image ready / PDF ready *(success header title)* |
| resultChecked | Checked and ready to save |
| resultSmallerShort | smaller *(under "−87%" in the savings ring)* |
| resultLargerShort | larger *(under "+132%" when the output is bigger than the input; shown in the warning colour)* |
| resultSize | Size *(third row beside the ring: dimensions or page count)* |
| i2pRunEmpty | Create PDF *(Images to PDF button before any image is chosen)* |

### 5.4 Ad diagnostics (hidden; ADR-035)
Settings → tap the version 7 times. Developer-facing; still in the ARB (`diag*` keys).

| Key (ARB) | Text |
|---|---|
| diagTitle | Ad diagnostics |
| diagSectionStatus / diagSectionSlots | Status / Ad slots |
| diagConsent / diagAdsRemoved | Consent allows ads: {answer} / Remove ads bought: {answer} (diagYes / diagNo: Yes / No) |
| diagAdFreeUntil / diagAdFreeNone | Ad-free pass until {time} / No ad-free pass active |
| diagBuildIds | This build uses: {kind} (diagIdsTest: Test IDs (debug build) · diagIdsReal: Real IDs (release build)) |
| diagUnitTest / Real / Off / Missing | Test ID / Real ID / Off / Missing |
| diagLoaded / diagNoFill | Loaded at {time} / No fill at {time} (code {code}) |
| diagError / diagErrorNoCode | Error at {time}: code {code}, {message} / Error at {time}: {message} |
| diagNotRequested | Not requested yet |
| diagPlace… | One line per slot, e.g. "Native card on Home (AD-1)", "Bottom banner: tool screens and Manage files" |

## 6. Formatting rules
- Sizes: base-1024, labelled KB/MB/GB (matching what upload portals usually compute); < 1 KB → "{n} B"; 1 decimal below 10 (e.g. 3.2 MB), none from 10 upwards (e.g. 410 KB, 18 MB). Locale-aware decimal separator (`intl.NumberFormat`).
- Percent change: `round((after − before) / before × 100)`; show "−87%" in the comparison and "87% smaller" in prose.
- Dates: today/yesterday → time only (`HH:mm` or the locale's 12 h); otherwise `d MMM yyyy`.
- Durations: < 1 s → "under a second"; otherwise "{n.n} s" / "{m} min {s} s".

## 7. Strings added during implementation (2026-10-26)
These are in `lib/l10n/app_en.arb` under the camelCase keys shown.

| Key | Text |
|---|---|
| actionClose / actionChange / actionApply / actionUndo / actionBack / actionInfo | Close / Change / Apply / Undo / Back / How it works |
| itemUnavailable | That item is no longer available. |
| homeGreeting | What do you need to do? |
| homeSearchExample1 / 2 / 3 | Search tools — "make photo smaller" / "combine PDFs" / "passport photo" |
| homeHistoryTooltip / homeSettingsTooltip / homeNavHome | Recent activity / Settings / Home |
| homeOfflineBadge | Works offline |
| searchFieldHint / searchClear / searchAllTools | Search tools / Clear search / ALL TOOLS |
| searchChipCompress / Combine / Passport / Rotate | compress / combine PDF / passport photo / rotate page |
| infoImageCompress / infoImageResize / infoImageToPdf / infoPdfMerge / infoPdfOrganize / infoPdfCompress | "How it works" sheet text per tool (see ARB) |
| pickLoading | Reading files… |
| inputsFileHeader / inputsOptionsHeader | FILE / OPTIONS |
| inputsAllInvalid | None of these files can be used. Choose different files. |
| badgeHasAlpha / badgeLocked / badgeDamaged / badgeUnsupported / badgeTooLarge / badgeUnreadable | Has transparency / Password-protected / Looks damaged / Not supported / Too large / Can't be read |
| metaPages / metaDims | {count} pages / {w} × {h} |
| cmpSectionHow / cmpQualityA11y / cmpTargetMin / cmpUnitKb / cmpUnitMb / cmpFormat / cmpMaxOriginal / cmpMaxPx / cmpRunAnyway | HOW SMALL? / Quality {value} percent / Enter at least 5 KB. / KB / MB / Output format / Original / {px} px / Compress anyway |
| fmtJpeg / fmtPng / fmtWebp / fmtHeic / fmtPdf | JPEG / PNG / WebP / HEIC / PDF |
| resSectionSize / resUnitPx / resScale / resPercentValue / resPadColor / resPadWhite / resPadBlack / resPadTransparent | SIZE / px / Scale / {p}% / Border colour / White / Black / Transparent |
| resMyPresets / resPresetNameHint / resPresetLimit / resDeletePreset / resQuality | My presets / Preset name / You can save up to 10 presets. / Delete preset / Quality |
| i2pSectionPage / i2pSectionQuality / i2pSizeA4 / i2pSizeLetter / i2pSizeLegal / i2pOrientPortrait / i2pOrientLandscape / i2pPreview / i2pOutputName / i2pRotate / i2pImageA11y | PAGE / QUALITY / A4 / Letter / Legal / Portrait / Landscape / PREVIEW / Output name / Rotate / Image {n} of {total} |
| i2pRemoveAndContinue | Remove and continue |
| mrgHeader / mrgTooManyPages / mrgSectionOutput / mrgName | PDFS ({count}) / Merged PDFs can have up to 2000 pages. / OUTPUT / Name |
| orgHint | Tap pages to select them. Long-press and drag to reorder. Double-tap to preview. |
| orgA11yPage / orgA11yRotated / orgA11ySelected / orgOrigPage / orgCantPreview | Page {pos} of {total} / rotated {deg} degrees / selected / p.{n} / Can't preview |
| orgUndo / orgRedo / orgMore / orgSelectAll / orgSelectNone / orgInvert / orgReset | Undo / Redo / More / Select all / Select none / Invert selection / Reset changes |
| orgDeleteConfirmTitle / orgDeleteConfirmBody / orgPreviewTitle | Delete {count} pages? / You can undo this before saving. / Page {pos} of {total} |
| redSectionLevel / redAnalysing | LEVEL / Analysing… |
| progressPages / progressImages / progressFiles | {done} of {total} pages / images / files |
| jobCancelTooltip / jobOnDevice | Cancel job / Processing on this device |
| resultNoChange / resultRetentionForever / resultKeepOriginal / resultTryLower | No change / Kept in Recent until you delete it / Keep original / Try lower quality |
| resultCompareHint / resultCompareA11y / resultOpen / resultA11ySummary / resultPreviewA11y | Drag to compare before and after / Before and after comparison / Open / Done. {before} to {after}. / Preview of the result |
| saveSheetTitle / saveFilesInstead / discardedSnack | Save to / Save to Files instead / Result discarded. |
| errCancelledTitle / errCancelledBody / errFileLabel | Cancelled / Nothing was saved. / File: {name} |
| errInvalidInputBody | Some options aren't valid. Go back and check them. |
| histEmptyTitle / histSortTooltip / histClearTooltip / histSortTitle / histSortLabel / histStatusLabel / histStatusAll / histStatusCompleted / histStatusFailed | No activity yet / Sort and filter / Clear history / Sort and filter / SORT / STATUS / All / Completed / Failed |
| histFailedLine / histCancelled / histInterrupted / histRunning / histSizes / histFilesPages / histLoadMore | Failed — {reason} / Cancelled / Interrupted / In progress / {before} → {after} / {files} files · {pages} pages · {size} / Show more |
| detSavedYes / detDeleted / detForever / detTook / detStatus* | Saved to device / Deleted / Until you delete it / took {duration} / Completed · Failed · Cancelled · Interrupted · In progress |
| detDeleteCopyTitle / detDeleteCopyBody / detRemoveTitle / detRemoveBody / detRepickHint | Delete the app copy? / Files you saved elsewhere are not affected. / Remove from history? / The app copy of the result will also be deleted. … / You'll need to choose the files again. |
| setSection* / setDefaultQuality / setDefaultFormat / setLockRatio / setPageSize / setImageFit / setMargins / setPdfImageQuality / setReduceLevel / setStorageCleared / setClearHistory / setHistoryCleared / setPrivacy | Settings labels (see ARB) |
| feedbackSubject / feedbackBody / feedbackUnavailable | DocuKit feedback / App version: {version} Device OS: {os} / No email app is set up on this device. |
| periodH24 / periodD7 / periodD30 / periodForever | 24 hours / 7 days / 30 days / until you delete them |
| privAccessPhotosLabel / privAccessFilesLabel / privAccessPhotosAddLabel | Photos / Files / Photos (add only) |
| privPolicyBody1…5 | The offline privacy policy (RELEASE §6, without the bracketed parts) |
| unsavedOrganizerBody | Your page edits haven't been saved. |
| renameTitle / renameHint / renameEmpty / renamePreview | Rename / File name / Enter a name. / Will be saved as {name} |
| fdTitle / fdName / fdType / fdSize / fdDimensions / fdPages / fdAlpha / fdLocation / fdProtected / fdYes / fdNo | D1 labels |
| moveToTitle / moveTop / moveUp / moveDown / moveBottom / dragHandle | Move to… / Move to top / Move up / Move down / Move to bottom / Drag to reorder |
| draftRestored / draftStartOver | Restored your last session. / Start over |
| durUnderSecond / durSeconds / durMinutes | under a second / {s} s / {m} min {s} s |

## 8. v3 releases (1.1–1.5)

Merged from each release spec's §7 in M0. Add these to `lib/l10n/app_en.arb` in the release that ships them, not before (ARB keys follow the spec names).

### 8.1 Version 1.1 — Productivity (batch, convert, split, PDF→images, extract, favourites, share-in) (RELEASE_V1_1 §7)

| Key | Text |
|---|---|
| tool_image_convert_title / subtitle | Convert Image / Change the file format |
| tool_pdf_split_title / subtitle | Split PDF / Break a PDF into parts |
| tool_pdf_to_images_title / subtitle | PDF to Images / Save pages as pictures |
| batch_header | Images ({count}) *(sentence case, UI_REFRESH §1)* |
| batch_total | Total {size} *(T8.5: split from the invalid count so there's no trailing " · " when it's 0; the UI joins them with " · ")* |
| batch_invalid | {count, plural, =1{1 can't be used} other{# can't be used}} |
| batch_remove_invalid | Remove them |
| batch_none_valid | Add images that DocuKit can open |
| batch_run_compress / resize / convert | Compress {count} images / Resize {count} images / Convert {count} images *(convert is a plural: "Convert 1 image" for one, since Convert has no separate single-image label; T8.7)* |
| batch_show_all | Show all {count} *(T8.5; S21 mockup)* |
| batch_clear_all | Clear all *(T8.5; S21 ⋮ menu)* |
| res_fit_inside | Fit inside *(T8.6; FR-BAT-12)* |
| res_fit_inside_hint | Each photo keeps its shape and fits inside {w} × {h} px. Smaller photos keep their size. *(T8.6; ADR-062)* |
| multi_header_all | All done |
| multi_header_some | {done} of {total} done |
| multi_totals | Before {before} → After {after} |
| multi_count_pdfs / images | {count} PDFs · {size} / {count} images · {size} |
| multi_save_all | Save all… |
| multi_save_zip | Save as ZIP |
| multi_share_all | Share all |
| multi_saved_folder | Saved {count} files to {folder} |
| multi_saved | Saved {count} files |
| multi_saved_partial | Saved {saved} of {total}. {failed} couldn't be written. |
| multi_share_too_many | That's more than 50 files. Share them as one ZIP instead? |
| multi_item_closest | Closest to {target} |
| multi_item_failed | {error}. Original not changed. |
| multi_all_failed | None of the files could be processed. Your originals were not changed. |
| multi_zipping | Zipping {done} of {total} *(T8.4; ZIP progress, wording from ADR-060)* |
| multi_files_header | Files *(T8.4; S22 list header; sentence case per UI_REFRESH §1)* |
| cnv_to | Convert to *(sentence case, UI_REFRESH §1)* |
| cnv_same_format | {count, plural, =1{1 image is} other{# images are}} already {format}. They'll be re-saved. |
| cnv_heic_ios_only | HEIC is available on iPhone only. *(shown under the format chips on Android, where HEIC is hidden)* |
| step_converting | Converting images… *(T8.7; progress step for Convert)* |
| spl_mode_ranges / every / each | Custom ranges / Every N pages / Each page |
| spl_how | How to split *(T8.8; S24 section title)* |
| spl_part_page / pages | page {page} / pages {first}–{last} *(T8.8; the parts in spl_preview_files, as in the S24 mockup)* |
| spl_each_preview | {count, plural, =1{1 file} other{# files}} *(T8.8; Each page preview)* |
| spl_every_less / more | Fewer pages per file / More pages per file *(T8.8; − / + tooltips)* |
| spl_ranges_hint | Use commas and dashes, e.g. 1-3, 5, 8-end |
| spl_preview_files | {count, plural, =1{1 file} other{# files}}: {parts} |
| spl_every_label | Pages per file |
| spl_every_preview | {count} files (the last has {lastPages, plural, =1{1 page} other{# pages}}) |
| spl_one_page | This PDF has only one page. |
| spl_each_cap | That would make more than 500 files. Use Every N pages instead. |
| spl_run | Split into {count, plural, =1{1 PDF} other{# PDFs}} *(=0 → "Split" while nothing valid is entered)* |
| range_err_page | Page {page} doesn't exist. This PDF has {total} pages. |
| range_err_reversed | Write ranges from low to high, e.g. 3-5. |
| range_err_zero | Pages start at 1. |
| range_err_chars | Use only numbers, commas, dashes and "end". |
| range_err_empty | Enter at least one page. |
| range_end_word | end |
| p2i_pages_all / choose | All pages / Choose pages |
| p2i_res_72 / 150 / 300 | Screen / Standard / Print *(shown as "72 · Screen" etc.)* |
| p2i_resolution | Resolution *(T8.9; S25 section title; Pages / Output format reuse fd_pages / cmp_format)* |
| p2i_px_estimate | ≈ {w} × {h} px per page |
| p2i_page_capped | Page {page} was limited to {px} px to save memory. |
| p2i_keep_transparent | Keep transparent background |
| p2i_run | Create {count, plural, =1{1 image} other{# images}} *(=0 → "Create images" while nothing valid is chosen)* |
| org_extract | Extract |
| org_extract_done_name | {base}_extract *(a file-name pattern, built in `file_naming.dart` like every other output name, not in ARB)* |
| fav_header | Favourites |
| fav_edit | Edit |
| fav_add / remove | Add to favourites / Remove from favourites |
| fav_limit | You can pin up to 6 tools. Remove one first. |
| fav_move_up / down | Move up / Move down |
| inc_title | Received {count, plural, =1{1 file} other{# files}} |
| inc_images_section / pdfs_section | {count, plural, =1{1 image} other{# images}} / {count, plural, =1{1 PDF} other{# PDFs}} |
| inc_merge_needs_more | Needs one more PDF. You can add it next. |
| inc_unsupported | DocuKit can't work with this file type. |
| inc_waiting | {count, plural, =1{1 file received} other{# files received}}. Open when this job finishes. |
| tour_image_convert_title / body / example | Convert Image / Change photos between JPG, PNG, WebP and HEIC. / Turn iPhone HEIC photos into JPG for upload forms. |
| tour_pdf_split_title / body / example | Split PDF / Break one PDF into several smaller ones. / Send only pages 3–5 of a long report. |
| tour_pdf_to_images_title / body / example | PDF to Images / Save each page as a picture. / Post a page of a PDF as a photo. |
| tour_favourites_title / body | Favourites / Long-press any tool to pin it here. |

### 8.2 Version 1.2 — Scan Document (RELEASE_V1_2 §7)

| Key | Text |
|---|---|
| tool_scan_title / subtitle | Scan Document / Turn paper into a PDF |
| home_section_scan | Scan & text |
| qa_scan | Scan |
| scn_entry_title | Scan pages with your camera |
| scn_entry_body | Edges are found and straightened for you. |
| scn_start | Start scanning |
| scn_have_photos | Have photos already? |
| scn_choose_photos | Choose photos instead |
| scn_preparing | Getting the scanner ready… |
| scn_err_module_offline | The scanner needs a one-time download. Connect to the internet and try again. |
| scn_err_unavailable_android | Scanning needs Google Play services, which isn't on this phone. |
| scn_err_unavailable_ios | This device can't scan documents. |
| scn_err_camera_denied | DocuKit can't use the camera. Allow it in Settings. |
| scn_err_unknown | The scanner closed unexpectedly. Try again. |
| scn_pages | {count, plural, =1{1 page} other{# pages}} |
| scn_add_pages | Add pages |
| scn_rescan_page | Rescan this page |
| scn_rotate_left / right | Rotate left / Rotate right |
| scn_page_menu | Page options |
| scn_truncated | Only the first {max} pages were kept. |
| scn_limit_reached | You've reached {max} pages. Save this scan to start a new one. |
| scn_save_as | Save as |
| scn_format_pdf / jpg | PDF / JPG images |
| scn_page_fit | Fit to scan |
| scn_quality_high / compact | High / Compact |
| scn_run_pdf | Save scan ({count, plural, =1{1 page} other{# pages}}) |
| scn_run_jpg | Save {count, plural, =1{1 image} other{# images}} |
| scn_discard_title / body | Discard this scan? / The scanned pages will be deleted. |
| scn_delete_last_title | Discard this scan? |
| step_saving_scan | Saving your scan… |
| tour_scan_title / body / example | Scan Document / Scan paper with your camera. Edges are found and straightened automatically. / Notes, receipts or a signed form in one PDF. |
| priv_access_camera_label | Camera |
| priv_access_camera | Camera, only while you're scanning |
| search keywords (`tool_scan_keywords`) | scan, scanner, camera, photo of document, paper, receipt, notes, digitize, capture, document camera |

### 8.3 Version 1.3 — Text Recognition (OCR) (RELEASE_V1_3 §7)

| Key | Text |
|---|---|
| tool_ocr_title / subtitle | Text Recognition / Find text in photos and scans |
| ocr_pick_images / pick_pdf | Choose images / Choose PDF |
| ocr_pick_hint | Up to 50 images or one PDF |
| ocr_mix_refused | Choose images or one PDF, not both. |
| ocr_checking_text | Checking for text… |
| ocr_badge_no_text / has_text / partial | No text yet / Already has text / Text on {n} of {total} pages |
| ocr_pdf_has_text | This PDF already has text you can search and copy. |
| ocr_pdf_partial | {n} of {total} pages already have text. Only the other pages will be recognised. |
| ocr_pdf_rebuild_note | Recognised pages are rebuilt from images. Links and form fields on those pages won't work. |
| ocr_results_header | Results |
| ocr_out_pdf / review / txt | Searchable PDF / Review and copy text / Save as .txt |
| ocr_out_pdf_disabled | Already searchable |
| ocr_need_output | Choose at least one result |
| ocr_language | Text language |
| ocr_lang_latin / devanagari / chinese / japanese / korean | Latin (English, Spanish, French…) / Devanagari (Hindi, Marathi…) / Chinese / Japanese / Korean |
| ocr_model_download | The {language} text model downloads once from Google Play (about {size}). |
| ocr_long_job | This may take a few minutes. Keep DocuKit open. |
| ocr_run | Recognise text ({count, plural, =1{1 page} other{# pages}}) |
| ocr_run_get_text | Get text |
| step_ocr_preparing / page / building | Getting text recognition ready… / Recognising page {n} of {total} / Building searchable PDF… |
| ocr_result_stats | {pages} pages · {words} words found |
| ocr_result_low_pages | {n} pages with little text |
| ocr_low_text_page | Little or no text found on page {n}. |
| ocr_low_text_all | We couldn't find much text. Try a sharper photo, or check the language. |
| ocr_review | Review text |
| ocr_copy_text / copy_page / copy_all | Copy text / Copy page / Copy all |
| ocr_copied | Copied |
| ocr_share_text | Share |
| ocr_save_txt | Save .txt |
| ocr_shared_as_file | Shared as a text file because it's long. |
| ocr_edited | Edited |
| ocr_too_long_to_edit | Text is too long to edit here. You can still copy or save it. |
| ocr_discard_edits | Discard your text changes? |
| ocr_text_only_history | Text only, not saved |
| scan_make_searchable | Make searchable (recognise text) |
| set_ocr_language | Text recognition language |
| priv_ocr_p | Text recognition runs on your phone. DocuKit doesn't upload your files or the text found in them. |
| err_ocrModelUnavailable_title / body | Text recognition isn't ready / The {language} model couldn't be downloaded. Connect to the internet once and try again, or choose Latin. |
| tour_ocr_title / body / example | Text Recognition / Find the text in photos and scans. Copy it, or make a PDF you can search. / Turn a photo of notes into text you can paste. |

### 8.4 Version 1.4 — Sign, Watermark, Protect, Unlock (RELEASE_V1_4 §7)

| Key | Text |
|---|---|
| tool_pdf_sign_title / subtitle | Sign PDF / Add your signature to pages |
| tool_pdf_watermark_title / subtitle | Watermark PDF / Stamp text or a logo on pages |
| tool_pdf_protect_title / subtitle | Protect PDF / Add a password |
| tool_pdf_unlock_title / subtitle | Unlock PDF / Remove a password you know |
| home_section_secure | Secure & Sign |
| sig_your_signature | Your signature |
| sig_draw / type / photo | Draw / Type / Photo |
| sig_new | New |
| sig_not_certified | This adds an image of your signature. It isn't a certified digital signature. |
| sig_place_cta | Place signature on pages |
| sig_pad_title_draw / type / photo | Draw signature / Type signature / Signature from photo |
| sig_pad_hint | Sign with your finger |
| sig_pad_landscape | Turn your phone for more room |
| sig_undo_stroke / clear | Undo / Clear |
| sig_colour / thickness | Colour / Thickness |
| sig_your_name | Your name |
| sig_bg_cleanup | Background cleanup |
| sig_save_ask_title / body | Save this signature for next time? / It's kept only on this phone and isn't included in backups. |
| sig_save_yes / no | Save / Not now |
| sig_saved_limit | You can keep up to 3 signatures. Delete one to save this. |
| sig_delete_title | Delete this saved signature? |
| sig_discard_title | Discard this signature? |
| sig_place_title | Place signature |
| sig_add_signature / date / text / initials | Signature / Date / Text / Initials |
| sig_pages_sheet | Add this to |
| sig_pages_all / range / this | All pages / Pages / Only this page |
| sig_need_one | Add your signature to at least one page. |
| sig_move_to | Move to |
| sig_bigger / smaller / rotate | Bigger / Smaller / Rotate 90° |
| sig_run | Save signed PDF |
| wmk_text / image | Text / Image |
| wmk_text_hint | Watermark text |
| wmk_need_text | Enter watermark text |
| wmk_position | Position |
| wmk_pos_diagonal / centre / tile / tl / tr / bl / br | Centre diagonal / Centre / Tile / Top left / Top right / Bottom left / Bottom right |
| wmk_size / opacity / rotation | Size / Opacity / Rotation |
| wmk_pages | Pages |
| wmk_pages_all / range / odd / even | All / Range / Odd / Even |
| wmk_range_hint / error | e.g. 1-3, 5 / Use page numbers like 1-3, 5 |
| wmk_on_top | The watermark is added on top of the page. |
| wmk_not_searchable (ⓘ sheet) | Text watermarks are added as an image, so they can't be selected or searched. |
| wmk_run | Add watermark |
| prt_password / confirm | Password / Confirm password |
| prt_show / hide (a11y) | Show password / Hide password |
| prt_strength_weak / ok / strong | Weak / OK / Strong |
| prt_err_short | Use at least 6 characters |
| prt_err_long | Use 64 characters or fewer |
| prt_err_mismatch | Passwords don't match |
| prt_no_recover | If you forget this password, nobody can open the file — DocuKit can't recover it. |
| prt_weak_title / body | This password is easy to guess / Use it anyway? |
| prt_weak_change / use | Change it / Use anyway |
| prt_already | This PDF already has a password. |
| prt_run | Protect PDF |
| unl_password | Password |
| unl_wrong | That password didn't work. Check it and try again. |
| unl_need_pw | You need the file's password. DocuKit can't unlock files without it. |
| unl_not_encrypted | This PDF doesn't have a password. |
| unl_owner_only | This PDF opens without a password. It has restrictions set by its creator, which DocuKit keeps. |
| unl_run | Unlock PDF |
| enc_unlock_first | This PDF is password-protected. Unlock it first. |
| enc_unlock_action | Unlock PDF |
| step_adding_stamps / encrypting / checking_password / unlocking | Adding to pages… / Adding password… / Checking password… / Removing password… |
| result_protected_note | Keep the password somewhere safe. |
| set_saved_signatures / delete_all | Saved signatures / Delete all saved signatures |
| priv_pw_sig_h / p | Passwords and signatures / Passwords you enter are used once and never saved. Saved signatures stay only on this phone and aren't included in backups. |
| tour_secure_title / body | Secure & Sign / Sign, watermark, or add and remove passwords — all on your phone. |
| tour_pdf_sign_example | Sign a rental agreement without printing it. |
| tour_pdf_watermark_example | Mark a document "Draft" or "Confidential". |
| tour_pdf_protect_example | Lock a bank statement before emailing it. |
| tour_pdf_unlock_example | Remove a password you know from a statement. |

---

### 8.5 Version 1.5 — My Documents, reminders, app lock (RELEASE_V1_5 §7)

> ⚠️ `rem_title` collides with the existing Remove ads key `remTitle`. Proposed: the reminder keys get the `rmd_` prefix in the ARB (DECISIONS conflict C-16).

| Key | Text |
|---|---|
| lib_title | My Documents |
| lib_intro_title | Keep important documents here |
| lib_intro_b1 | Stored only on this phone |
| lib_intro_b2 | Not included in cloud backups. You can export a backup anytime. |
| lib_intro_b3 | Deleted if you uninstall DocuKit |
| lib_intro_cta | Get started |
| lib_intro_backup_link | Learn about backups |
| lib_empty_title / body | No documents yet / Tip: tap "Save to My Documents" on any result. |
| lib_import / scan / new_folder | Import files / Scan a document / New folder |
| lib_search_hint | Search names, notes and text |
| lib_filter_all / starred | All / Starred |
| lib_section_expiring / folders / documents | Expiring soon / Folders / Documents |
| lib_expires_in | Expires in {days, plural, =0{today} =1{1 day} other{# days}} |
| lib_expired_ago | Expired {days, plural, =0{today} =1{1 day ago} other{# days ago}} |
| lib_save_to | Save to My Documents |
| lib_saved_snack / view | Saved to My Documents / View |
| lib_dup_title / body | Already in My Documents / This file is already saved as {name} in {folder}. Add another copy? |
| lib_dup_open / add | Open existing / Add copy |
| lib_move_title / here / save_here | Move {count, plural, =1{1 item} other{# items}} to… / Move here / Save here |
| lib_root | My Documents |
| lib_folder_depth | Folders can be 3 levels deep |
| lib_folder_name_taken | A folder with this name already exists here |
| lib_delete_doc_title / body | Delete "{name}"? / This can't be undone. |
| lib_delete_folder_title | Delete folder "{name}"? |
| lib_delete_folder_body | It contains {docs} documents and {folders} folders. |
| lib_delete_folder_move / all | Move contents up / Delete everything |
| lib_open_in_tool | Open in tool… |
| lib_notes_hint | Add notes (only you can see them) |
| lib_searchable_yes / no / now | Searchable · Text recognised / Not searchable / Make searchable now |
| lib_indexing | Making {count} documents searchable… |
| lib_index_paused_battery | Paused while the battery is low |
| lib_file_missing | File missing |
| lib_gone | That document is no longer in My Documents. |
| rem_title / quick_1y / 5y / 10y / none | Expiry date / 1 year / 5 years / 10 years / No expiry |
| rem_remind_me / d30 / d7 / d1 / d0 | Remind me / 30 days before / 7 days before / 1 day before / On the day |
| rem_at_time | At {time} |
| rem_next | Next reminder: {date} |
| rem_remove | Remove expiry |
| rem_blocked | Notifications are blocked, so reminders won't appear. |
| rem_notif_title | Document expiring |
| rem_notif_body_generic | A document expires {days, plural, =0{today} =1{tomorrow} other{in # days}}. |
| rem_notif_body_named | {name} expires {days, plural, =0{today} =1{tomorrow} other{in # days}}. |
| rem_snooze | Remind me tomorrow |
| rem_channel_name / desc | Document reminders / Reminders before documents expire |
| lck_title / body | My Documents is locked / Use your fingerprint, face or screen lock to continue. |
| lck_unlock / back_home | Unlock / Back to Home |
| lck_reason | Unlock My Documents |
| lck_no_screen_lock | Set up a screen lock on your phone first. |
| lck_removed | Your phone's screen lock was removed. Turn off the DocuKit lock to keep using My Documents. |
| set_lib_* | My Documents settings / Make documents searchable / Scans / Other PDFs and images / Reminder time / Show document names in reminders / Lock My Documents / What to lock / My Documents only / Whole app / Lock after leaving / Immediately / 1 minute / 5 minutes / Hide in recent apps / Also blocks screenshots on these screens / Export library / Import backup |
| set_lib_backup_note | My Documents isn't included in iCloud or Google backups. Export a backup before changing or resetting your phone. Uninstalling DocuKit deletes these documents. |
| exp_done / imp_summary | Library exported / Imported {added} · Skipped {dups} duplicates{bad, plural, =0{} =1{ · 1 damaged file} other{ · # damaged files}} |
| priv_lib_h / p | My Documents and reminders / Documents you save to My Documents stay on this phone. They aren't included in cloud backups and are deleted if you uninstall DocuKit. Reminders are notifications created on your phone. |

---
