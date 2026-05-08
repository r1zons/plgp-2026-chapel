CHPL ?= chpl
SRC_DIR := src
BIN_DIR := bin
TEST_DIR := test
TARGET := $(BIN_DIR)/bc_compare

MAIN_SRC := $(SRC_DIR)/Main.chpl

.PHONY: all check-chpl build run generate test test-generator test-brandes test-brandes-parallel test-partitioned-state test-partitioned-graph test-partitioned-messages test-partitioned-bfs test-partitioned-brandes test-partitioned-brandes-parallel clean

all: build

check-chpl:
	@command -v $(CHPL) >/dev/null 2>&1 || { echo "Error: Chapel compiler '$(CHPL)' not found in PATH."; echo "Install Chapel or invoke make with CHPL=/path/to/chpl."; exit 127; }

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

build: check-chpl $(BIN_DIR)
	$(CHPL) $(MAIN_SRC) -o $(TARGET)

generate: build
	./$(TARGET) --command=Generate --n=10 --seed=1

run: build
	./$(TARGET) --command=Run --n=10 --seed=1

test: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestCompare.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_compare
	./$(BIN_DIR)/test_compare
	$(CHPL) $(TEST_DIR)/TestGraphGenerator.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_generator
	./$(BIN_DIR)/test_generator
	$(CHPL) $(TEST_DIR)/TestNaiveBC.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_naive_bc
	./$(BIN_DIR)/test_naive_bc
	$(CHPL) $(TEST_DIR)/TestBrandesBC.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_brandes_bc
	./$(BIN_DIR)/test_brandes_bc
	$(CHPL) $(TEST_DIR)/TestBrandesBCParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_brandes_bc_parallel
	./$(BIN_DIR)/test_brandes_bc_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedGraph.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_graph
	./$(BIN_DIR)/test_partitioned_graph
	$(CHPL) $(TEST_DIR)/TestPartitionedMessages.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages
	./$(BIN_DIR)/test_partitioned_messages
	$(CHPL) $(TEST_DIR)/TestPartitionedMessagesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages_parallel
	./$(BIN_DIR)/test_partitioned_messages_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedBFS.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_bfs
	./$(BIN_DIR)/test_partitioned_bfs
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandes.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes
	./$(BIN_DIR)/test_partitioned_brandes
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes_parallel
	./$(BIN_DIR)/test_partitioned_brandes_parallel

clean:
	rm -rf $(BIN_DIR)


test-brandes: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestBrandesBC.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_brandes_bc
	./$(BIN_DIR)/test_brandes_bc
	$(CHPL) $(TEST_DIR)/TestBrandesBCParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_brandes_bc_parallel
	./$(BIN_DIR)/test_brandes_bc_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedGraph.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_graph
	./$(BIN_DIR)/test_partitioned_graph
	$(CHPL) $(TEST_DIR)/TestPartitionedMessages.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages
	./$(BIN_DIR)/test_partitioned_messages
	$(CHPL) $(TEST_DIR)/TestPartitionedMessagesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages_parallel
	./$(BIN_DIR)/test_partitioned_messages_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedBFS.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_bfs
	./$(BIN_DIR)/test_partitioned_bfs
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandes.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes
	./$(BIN_DIR)/test_partitioned_brandes
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes_parallel
	./$(BIN_DIR)/test_partitioned_brandes_parallel


test-partitioned-graph: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedState.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_state
	./$(BIN_DIR)/test_partitioned_state
	$(CHPL) $(TEST_DIR)/TestPartitionedGraph.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_graph
	./$(BIN_DIR)/test_partitioned_graph
	$(CHPL) $(TEST_DIR)/TestPartitionedMessages.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages
	./$(BIN_DIR)/test_partitioned_messages
	$(CHPL) $(TEST_DIR)/TestPartitionedMessagesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages_parallel
	./$(BIN_DIR)/test_partitioned_messages_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedBFS.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_bfs
	./$(BIN_DIR)/test_partitioned_bfs
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandes.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes
	./$(BIN_DIR)/test_partitioned_brandes


test-partitioned-messages: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedMessages.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages
	./$(BIN_DIR)/test_partitioned_messages
	$(CHPL) $(TEST_DIR)/TestPartitionedMessagesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_messages_parallel
	./$(BIN_DIR)/test_partitioned_messages_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedBFS.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_bfs
	./$(BIN_DIR)/test_partitioned_bfs
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandes.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes
	./$(BIN_DIR)/test_partitioned_brandes


test-partitioned-bfs: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedBFS.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_bfs
	./$(BIN_DIR)/test_partitioned_bfs
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandes.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes
	./$(BIN_DIR)/test_partitioned_brandes


test-partitioned-brandes: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandes.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes
	./$(BIN_DIR)/test_partitioned_brandes
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes_parallel
	./$(BIN_DIR)/test_partitioned_brandes_parallel

test-partitioned-brandes-parallel: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedBrandesParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_brandes_parallel
	./$(BIN_DIR)/test_partitioned_brandes_parallel

test-partitioned-state: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedState.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_state
	./$(BIN_DIR)/test_partitioned_state

test-generator: check-chpl $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestGraphGenerator.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_generator
	./$(BIN_DIR)/test_generator
