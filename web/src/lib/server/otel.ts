import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-proto';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-proto';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { ATTR_SERVICE_NAME } from '@opentelemetry/semantic-conventions';
import { SpanKind, SpanStatusCode, context, propagation, trace } from '@opentelemetry/api';
import { isRedirect } from '@sveltejs/kit';
import type { Handle } from '@sveltejs/kit';
import { stopKafkaConsumer } from './kafka';

const sdk = new NodeSDK({
	resource: resourceFromAttributes({ [ATTR_SERVICE_NAME]: 'hempire-bff' }),
	traceExporter: new OTLPTraceExporter(),
	metricReader: new PeriodicExportingMetricReader({
		exporter: new OTLPMetricExporter(),
		exportIntervalMillis: 15_000
	}),
	instrumentations: [
		getNodeAutoInstrumentations({
			'@opentelemetry/instrumentation-fs': { enabled: false }
		})
	]
});

sdk.start();

const shutdown = async () => {
	await stopKafkaConsumer();
	await sdk.shutdown();
	process.exit(0);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

const tracer = trace.getTracer('hempire-bff');

export const telemetryHandle: Handle = async ({ event, resolve }) => {
	const parentCtx = propagation.extract(
		context.active(),
		Object.fromEntries(event.request.headers)
	);
	return context.with(parentCtx, () =>
		tracer.startActiveSpan(
			`${event.request.method} ${event.url.pathname}`,
			{ kind: SpanKind.SERVER },
			async (span) => {
				try {
					const response = await resolve(event);
					span.setAttribute('http.response.status_code', response.status);
					span.setStatus({ code: SpanStatusCode.OK });
					return response;
				} catch (err) {
					if (isRedirect(err)) {
						span.setAttribute('http.response.status_code', err.status);
						span.setStatus({ code: SpanStatusCode.OK });
						throw err;
					}
					span.recordException(err as Error);
					span.setStatus({ code: SpanStatusCode.ERROR });
					throw err;
				} finally {
					span.end();
				}
			}
		)
	);
};
