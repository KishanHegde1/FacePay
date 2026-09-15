/// The same camera and liveness pipeline serves both enrollment and a demo
/// approval. A successful blink check is not, by itself, face recognition.
enum FaceScanPurpose { scan, enrollment, demoPaymentApproval }
