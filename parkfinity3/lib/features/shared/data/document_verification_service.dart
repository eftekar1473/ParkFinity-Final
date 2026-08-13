import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final documentVerificationProvider = Provider<DocumentVerificationService>((ref) {
  return DocumentVerificationService();
});

/// Result of an on-device document check.
class DocVerifyResult {
  final bool valid;
  final String reason; // user-facing message when invalid

  const DocVerifyResult(this.valid, this.reason);
}

/// On-device document verification using Google ML Kit text recognition.
///
/// Fully free, no API key, no quota, works offline. We do not have an NID
/// database to verify identity — the goal here is only to ensure the uploaded
/// photo is actually the expected document (an ID card / license) and not a
/// selfie, a car, or a random picture, before we store it as fraud evidence.
class DocumentVerificationService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Keywords that strongly indicate a Bangladeshi NID card.
  static const _nidKeywords = [
    'NATIONAL ID', 'NATIONAL', 'IDENTITY', 'ID CARD', 'জাতীয়', 'পরিচয়',
    'GOVERNMENT', "PEOPLE'S REPUBLIC", 'BANGLADESH', 'NID', 'DATE OF BIRTH',
    'ID NO', 'NID NO',
  ];

  // The BACK of a BD NID carries no "National ID" title and no photo — it has
  // an address block, blood group, issue date, and a barcode/QR. Front-side
  // keyword matching wrongly rejects it. These are the back-side signals.
  static const _nidBackKeywords = [
    'ADDRESS', 'BLOOD', 'GROUP', 'PLACE OF BIRTH', 'ISSUE', 'DATE',
    'REPUBLIC', 'BANGLADESH', 'GOVERNMENT', 'POST OFFICE', 'HOLDING',
    'ঠিকানা', 'রক্ত', 'গ্রুপ', 'জন্মস্থান', 'বাংলাদেশ', 'সরকার', 'ডাকঘর',
  ];

  static const _licenseKeywords = [
    'DRIVING', 'DRIVER', 'LICENCE', 'LICENSE', 'DL NO', 'BRTA',
    'MOTOR', 'VEHICLE', 'CLASS',
  ];

  Future<String> _extractText(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(input);
    return recognized.text.toUpperCase();
  }

  bool _hasIdNumber(String text) {
    // NID / license carry a long numeric id (10, 13 or 17 digits typical in BD),
    // possibly spaced. Look for a run of >=6 digits.
    return RegExp(r'\d[\d\s]{5,}').hasMatch(text);
  }

  int _keywordHits(String text, List<String> keywords) {
    var hits = 0;
    for (final k in keywords) {
      if (text.contains(k)) hits++;
    }
    return hits;
  }

  /// Verify the image is an NID card (front or back). Accepts if it reads like
  /// an ID: at least one strong keyword AND a plausible id-number, OR two+
  /// keywords. Rejects photos with little/no text (selfies, cars, scenery).
  Future<DocVerifyResult> verifyNid(File imageFile) async {
    try {
      final text = await _extractText(imageFile);
      if (text.trim().length < 12) {
        return const DocVerifyResult(false,
            'This does not look like an NID. No document text was detected — please capture the card clearly in good light.');
      }
      final hits = _keywordHits(text, _nidKeywords);
      final hasId = _hasIdNumber(text);
      final ok = (hits >= 1 && hasId) || hits >= 2;
      return ok
          ? const DocVerifyResult(true, '')
          : const DocVerifyResult(false,
              'This does not look like a National ID card. Please upload a clear photo of your NID.');
    } catch (e) {
      return DocVerifyResult(false, 'Could not read the image. Please try another photo. ($e)');
    }
  }

  /// Verify the BACK of an NID. The back has no photo and no "National ID"
  /// title, so it is checked leniently: it must simply read like the reverse of
  /// a government card (address / blood group / issue date / barcode text),
  /// which still rejects a selfie, a car, or blank scenery.
  Future<DocVerifyResult> verifyNidBack(File imageFile) async {
    try {
      final text = await _extractText(imageFile);
      if (text.trim().length < 15) {
        return const DocVerifyResult(false,
            'This does not look like the back of an NID. No text was detected — please capture the back of the card clearly in good light.');
      }
      final hits = _keywordHits(text, _nidBackKeywords);
      // Accept on any back-side keyword, OR a long id/barcode number, OR simply
      // a text-dense card (the back is mostly an address paragraph).
      final ok = hits >= 1 || _hasIdNumber(text) || text.trim().length >= 40;
      return ok
          ? const DocVerifyResult(true, '')
          : const DocVerifyResult(false,
              'This does not look like the back of a National ID card. Please upload a clear photo of the back of your NID.');
    } catch (e) {
      return DocVerifyResult(false, 'Could not read the image. Please try another photo. ($e)');
    }
  }

  /// Verify the image is a driving license.
  Future<DocVerifyResult> verifyLicense(File imageFile) async {
    try {
      final text = await _extractText(imageFile);
      if (text.trim().length < 12) {
        return const DocVerifyResult(false,
            'No document text detected. Please upload a clear photo of your driving license.');
      }
      final hits = _keywordHits(text, _licenseKeywords);
      final hasId = _hasIdNumber(text);
      final ok = (hits >= 1 && hasId) || hits >= 2;
      return ok
          ? const DocVerifyResult(true, '')
          : const DocVerifyResult(false,
              'This does not look like a driving license. Please upload a clear photo of your license.');
    } catch (e) {
      return DocVerifyResult(false, 'Could not read the image. Please try another photo. ($e)');
    }
  }

  /// Property documents are varied (deeds, utility bills, ownership papers).
  /// We only require that the image contains a meaningful amount of text, so a
  /// random selfie/scenery is rejected but any genuine document passes.
  Future<DocVerifyResult> verifyPropertyDoc(File imageFile) async {
    try {
      final text = await _extractText(imageFile);
      final ok = text.trim().length >= 25;
      return ok
          ? const DocVerifyResult(true, '')
          : const DocVerifyResult(false,
              'This does not look like a document. Please upload a clear photo of your property paper.');
    } catch (e) {
      return DocVerifyResult(false, 'Could not read the image. Please try another photo. ($e)');
    }
  }

  void dispose() => _recognizer.close();
}
