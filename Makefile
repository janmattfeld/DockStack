NAME=devstack2

.PHONY: all build clean run stop test

all: build run

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

build:
	docker build \
		--tag $(NAME) \
		.

# TODO: Documentation of tmpfs and volumes
run:
	docker run \
		--name $(NAME) \
		--privileged \
		--tmpfs /run \
		--tmpfs /run/lock \
		--volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
		--detach \
		$(NAME)
	docker exec \
		--tty \
		--interactive \
		$(NAME) \
		bash -c "su stack -c '/devstack/stack.sh'"

# TODO: Add a container and ping 8.8.8.8
test:
