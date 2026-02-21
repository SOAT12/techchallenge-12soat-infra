output "api_gateway_webhook_url" {
  description = "The HTTPS URL to provide to Mercado Pago"
  value       = "${aws_apigatewayv2_api.webhook_proxy.api_endpoint}/api/v1/webhooks/mercadopago"
}

output "stock_add_event_queue_arn" {
  value = aws_sqs_queue.stock_add_event.arn
}

output "stock_remove_event_queue_arn" {
  value = aws_sqs_queue.stock_remove_event.arn
}

output "os_status_update_event_queue_arn" {
  value = aws_sqs_queue.os_status_update_event.arn
}
