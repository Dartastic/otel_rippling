// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_rippling/otel_rippling.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_rippling-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) => {
    for (final a in s.attributes.toList()) a.key: a.value,
  };

  test('devices.assign records product + device status', () async {
    await tracedRippling<String>(
      operation: 'devices.assign',
      product: 'device_management',
      invoke: () async => const RipplingCallResult(
        value: 'ok',
        result: RipplingResult(
          product: 'device_management',
          deviceStatus: 'provisioned',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('rippling devices.assign')!);
    expect(a['rippling.product'], 'device_management');
    expect(a['rippling.device.status'], 'provisioned');
  });

  test('global payroll records pay.country_code', () async {
    await tracedRippling<String>(
      operation: 'payrolls.runs.submit',
      invoke: () async => const RipplingCallResult(
        value: 'ok',
        result: RipplingResult(
          product: 'finance',
          payCountryCode: 'GB',
          employmentStatus: 'ACTIVE',
          workLocation: 'REMOTE',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('rippling payrolls.runs.submit')!);
    expect(a['rippling.pay.country_code'], 'GB');
    expect(a['rippling.work_location'], 'REMOTE');
  });

  test('suppression skips spans', () async {
    await runWithoutRipplingInstrumentationAsync(() async {
      await tracedRippling<String>(
        operation: 'employees.list',
        invoke: () async => const RipplingCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('rippling '), isEmpty);
  });
}
