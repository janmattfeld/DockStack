NAME=dockstack

.PHONY: all bash build clean lint run stop test

all: lint build run test

stop:
	docker ps \
		--quiet \
		--filter ancestor=$(NAME) \
	| xargs \
		--no-run-if-empty \
		docker stop
		
clean: stop
	docker system prune \
		--force

lint:
	docker run \
		--tty \
		--interactive \
		--rm \
		--volume "$(PWD)/Dockerfile:/Dockerfile:ro" \
		redcoolbeans/dockerlint

build:
	docker build \
		--tag $(NAME) \
		--build-arg BUILD_DATE=`date --utc +"%Y-%m-%dT%H:%M:%SZ"` \
		--build-arg VCS_REF=`git rev-parse --short HEAD` \
		--build-arg VERSION="test" \
		.

# Beware: This container runs in privileged mode!
#  - https://github.com/moby/moby/issues/24387#issuecomment-249195810
# TODO: Specify least needed rights and mounts
#  - https://github.com/solita/docker-systemd 
run:
	docker run \
		--name $(NAME) \
		--privileged \
		--detach \
		$(NAME)
	docker exec \
		--tty \
		--interactive \
		$(NAME) \
		bash -c "su stack -c '/devstack/stack.sh'"

test:
	docker exec \
		--tty \
		--interactive \
		$(NAME) \
		bash -c "su stack -c '\
			source /devstack/openrc admin admin && \
			zun run --name test cirros ping -c 4 8.8.8.8 \
		'"

bash:
	docker exec \
		--tty \
		--interactive \
		$(NAME) \
		bash
