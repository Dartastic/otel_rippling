// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_rippling_suppression.dart';

const _tracerName = 'dartastic_otel_libs_rippling';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class RipplingResult {
  /// Creates a result.
  const RipplingResult({
    this.itemCount,
    this.product,
    this.employmentStatus,
    this.workLocation,
    this.deviceStatus,
    this.appProvisioningStatus,
    this.payCountryCode,
    this.requestId,
    this.statusCode,
  });

  /// Items returned.
  final int? itemCount;

  /// `hr` / `it` / `finance` / `device_management` / `app_management`
  /// — Rippling sells modular products, distinct licensing.
  final String? product;

  /// `ACTIVE` / `TERMINATED` / `ON_LEAVE` / `PRE_HIRE`.
  final String? employmentStatus;

  /// `REMOTE` / `OFFICE` / `HYBRID` — affects tax + benefits routing.
  final String? workLocation;

  /// Device lifecycle: `enrolled` / `provisioned` / `wiped` /
  /// `retired`.
  final String? deviceStatus;

  /// `granted` / `pending` / `revoked` — app provisioning state.
  final String? appProvisioningStatus;

  /// ISO 3166 country (US, GB, CA, ...). Global payroll spans many
  /// payroll engines under Rippling — slice latency by country.
  final String? payCountryCode;

  /// Request id (`X-Rippling-Request-Id`).
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class RipplingCallResult<T> {
  /// Creates a call result.
  const RipplingCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final RipplingResult? result;
}

/// Wraps a Rippling API call in a CLIENT span. [operation] is one of
/// `employees.list`, `employees.get`, `employees.terminate`,
/// `payrolls.runs.list`, `payrolls.runs.submit`, `time_entries.list`,
/// `devices.list`, `devices.assign`, `devices.wipe`, `apps.list`,
/// `apps.grant`, `apps.revoke`, `expenses.list`, `expenses.approve`,
/// `companies.get`, `webhooks.create`.
Future<T> tracedRippling<T>({
  required String operation,
  required Future<RipplingCallResult<T>> Function() invoke,
  String? product,
}) async {
  if (ripplingInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'rippling',
    'rpc.method': operation,
    'rippling.operation': operation,
  };
  if (product != null) m['rippling.product'] = product;

  final span = _tracer().startSpan(
    'rippling $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(
          OTelAPI.attributeInt('rippling.item_count', r.result!.itemCount!),
        );
      }
      if (r.result!.product != null) {
        extras.add(
          OTelAPI.attributeString('rippling.product', r.result!.product!),
        );
      }
      if (r.result!.employmentStatus != null) {
        extras.add(
          OTelAPI.attributeString(
            'rippling.employment.status',
            r.result!.employmentStatus!,
          ),
        );
      }
      if (r.result!.workLocation != null) {
        extras.add(
          OTelAPI.attributeString(
            'rippling.work_location',
            r.result!.workLocation!,
          ),
        );
      }
      if (r.result!.deviceStatus != null) {
        extras.add(
          OTelAPI.attributeString(
            'rippling.device.status',
            r.result!.deviceStatus!,
          ),
        );
      }
      if (r.result!.appProvisioningStatus != null) {
        extras.add(
          OTelAPI.attributeString(
            'rippling.app.provisioning.status',
            r.result!.appProvisioningStatus!,
          ),
        );
      }
      if (r.result!.payCountryCode != null) {
        extras.add(
          OTelAPI.attributeString(
            'rippling.pay.country_code',
            r.result!.payCountryCode!,
          ),
        );
      }
      if (r.result!.requestId != null) {
        extras.add(
          OTelAPI.attributeString('rippling.request.id', r.result!.requestId!),
        );
      }
      if (r.result!.statusCode != null) {
        extras.add(
          OTelAPI.attributeInt(
              'http.response.status_code', r.result!.statusCode!),
        );
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Rippling HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(
      OTelAPI.attributes([
        OTelAPI.attributeString(
          ErrorAttributes.errorType.key,
          e.runtimeType.toString(),
        ),
      ]),
    );
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
