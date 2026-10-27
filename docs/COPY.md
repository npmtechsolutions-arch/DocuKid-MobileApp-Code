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
