output "api_gateway_webhook_url" {
  description = "The HTTPS URL to provide to Mercado Pago"
  value       = "${aws_apigatewayv2_api.webhook_proxy.api_endpoint}/api/v1/webhooks/mercadopago"
}
