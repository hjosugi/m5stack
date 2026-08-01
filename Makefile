<<<<<<< HEAD
.PHONY: backup build build-stackchan check detect docs fetch-stackchan grant init install-community list matrix monitor restore select setup setup-stackchan upload
||||||| 25f29cd
.PHONY: backup build build-stackchan check detect fetch-stackchan grant init list matrix monitor restore select setup setup-stackchan upload
=======
.PHONY: backup build build-cardputer-screen-link build-stackchan build-stackchan-screen-link check detect fetch-stackchan grant init list matrix monitor restore select setup setup-stackchan upload
>>>>>>> agent/pc-screen-link

detect:
	./scripts/detect-device.sh

init:
	./scripts/init-env.sh

list:
	./scripts/select-board.sh list

select:
	@test -n "$(MODEL)" || { echo "MODELを指定してください。例: make select MODEL=cores3" >&2; exit 2; }
	./scripts/select-board.sh "$(MODEL)"

setup:
	./scripts/setup.sh

fetch-stackchan:
	./scripts/fetch-stackchan.sh

setup-stackchan:
	./scripts/setup-stackchan-factory.sh

build-stackchan:
	./scripts/build-stackchan-factory.sh

build-cardputer-screen-link:
	./cardputer/screen-link/build.sh

build-stackchan-screen-link:
	./stackchan/screen-link/build.sh

build:
	./scripts/build.sh

matrix:
	./scripts/build-matrix.sh

grant:
	./scripts/grant-port-access.sh

backup:
	@echo "リセット許可を明示するため、./scripts/backup-flash.sh --allow-reset を直接実行してください。" >&2
	@exit 2

upload:
	@echo "Flash許可を明示するため、./scripts/upload.sh --allow-flash を直接実行してください。" >&2
	@exit 2

install-community:
	@echo "工場版置換の許可を明示するため、./scripts/install-community-stackchan.sh --allow-flash --replace-factory-firmware を直接実行してください。" >&2
	@exit 2

monitor:
	@echo "リセットの可能性を許可するため、./scripts/monitor.sh --allow-reset を直接実行してください。" >&2
	@exit 2

restore:
	@echo "復旧元を明示するため、./scripts/restore-flash.sh --allow-flash <flash.bin> を直接実行してください。" >&2
	@exit 2

check:
	./scripts/check.sh

docs:
	mkdocs build --strict
