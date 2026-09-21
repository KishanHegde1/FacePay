/// The same camera and liveness pipeline serves enrollment and recipient
/// discovery. A successful blink check is not, by itself, face recognition or
/// payment authorization.
enum FaceScanPurpose { scan, enrollment, recipientIdentification }
