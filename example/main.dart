// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_rippling/otel_rippling.dart';

/// Traces Rippling calls with OpenTelemetry.
///
/// `otel_rippling` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Rippling call in
/// [tracedRippling]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'rippling-example');

  // Wraps a Rippling API call in a CLIENT span.
  final ripplingId = await tracedRippling<String>(
    operation: 'webhooks.create',
    product: 'example',
    invoke: () async {
      // Make the Rippling call here, then report what it returned.
      const id = 'rippling_8f3a2c';
      return const RipplingCallResult(
          value: id,
          result: RipplingResult(
              itemCount: 3,
              product: 'hr',
              employmentStatus: 'ACTIVE',
              workLocation: 'REMOTE',
              deviceStatus: 'enrolled',
              appProvisioningStatus: 'granted',
              payCountryCode: 'example',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedRippling webhooks.create returned $ripplingId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutRipplingInstrumentationAsync.
  await runWithoutRipplingInstrumentationAsync(
    () => tracedRippling<String>(
      operation: 'webhooks.create',
      product: 'example',
      invoke: () async {
        const id = 'rippling_8f3a2c';
        return const RipplingCallResult(
            value: id,
            result: RipplingResult(
                itemCount: 3,
                product: 'hr',
                employmentStatus: 'ACTIVE',
                workLocation: 'REMOTE',
                deviceStatus: 'enrolled',
                appProvisioningStatus: 'granted',
                payCountryCode: 'example',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
