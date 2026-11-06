# Data Safety and reviewer worksheet — draft, owner sign-off required

Do not mark this as final solely because the build passes. Match the current Console form and Firebase SDK documentation. App has no Ads, Analytics or Crashlytics product explicitly integrated; Firebase technical service data still needs review.

| Data | Source and use | Collection / purpose review |
| --- | --- | --- |
| Name, phone account ID, email, Firebase UID | Registration, profile, authentication | Account management and app functionality; name/phone/email required at registration |
| Postal address (user profile) | Optional field typed by the user | Profile functionality; it is not the developer's public postal address |
| Financial information | Income/expense amounts, dates, categories, notes, splits and trip records | App functionality and account synchronization; no bank account/payment processing |
| Other people's names/numbers | Manually entered friend records | App functionality; does not access device Contacts permission or address book |
| Feedback / other user content | Rating, type, message, contact email, timestamp | Developer communications/support |
| SDK technical data and identifiers | Firebase Auth/Database connection and service operation | Review Firebase disclosures for device IDs, IP-derived location, diagnostics and fraud prevention; do not answer 'no device data' without that review |

All account/cloud data above leaves the device for Firebase. Treat it as collection, not only ephemeral processing. Review the service-provider exception before marking Firebase transfers as 'sharing'; user-selected exports can have a separate user-initiated transfer treatment. Do not automatically mark every transfer 'not shared'. TLS is used in transit; no end-to-end encryption claim.

Deletion: in app Profile > Delete Account; public request page pending hosting. Financial roots, feedback and profile contact fields are removed before Auth deletion. Minimal phone-ID/UID/deletion marker is retained without automatic expiry for ownership security/retry safety; disclose it and confirm justified retention. Exports and other users' independently entered records cannot be recalled. Provider backups/logs need owner confirmation.

Reviewer: privately provide a dedicated supported phone-ID/password account, synthetic records and all navigation instructions in App access. No OTP is used. Explain offline requirements, forms and deletion steps. Never post credentials publicly or disable rules for reviewers.

Financial features declaration: all apps must complete it; review current choices for expense/budget/money-management functions. No loans, money transfer, bank integration, investments or cryptocurrency execution exist in the reviewed source. Content-rating/age answers and developer identity verification require owner review.
