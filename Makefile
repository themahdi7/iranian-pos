.PHONY: runtime sep iran-kish sep-down iran-kish-down

runtime:
	docker build -t iranian-pos-wine:latest runtime/wine-dotnet

sep:
	docker compose -f psp/sep/compose.yaml up -d --build

sep-down:
	docker compose -f psp/sep/compose.yaml down

iran-kish:
	docker compose -f psp/iran-kish/compose.yaml up -d --build

iran-kish-down:
	docker compose -f psp/iran-kish/compose.yaml down
