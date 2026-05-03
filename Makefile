CHPL ?= chpl
SRC_DIR := src
BIN_DIR := bin
TEST_DIR := test
TARGET := $(BIN_DIR)/bc_compare

MAIN_SRC := $(SRC_DIR)/Main.chpl

.PHONY: all build run generate test test-brandes test-brandes-parallel test-partitioned-graph clean

all: build

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

build: $(BIN_DIR)
	$(CHPL) $(MAIN_SRC) -o $(TARGET)

generate: build
	./$(TARGET) --command=Generate --n=10 --seed=1

run: build
	./$(TARGET) --command=Run --n=10 --seed=1

test:
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

clean:
	rm -rf $(BIN_DIR)


test-brandes: $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestBrandesBC.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_brandes_bc
	./$(BIN_DIR)/test_brandes_bc
	$(CHPL) $(TEST_DIR)/TestBrandesBCParallel.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_brandes_bc_parallel
	./$(BIN_DIR)/test_brandes_bc_parallel
	$(CHPL) $(TEST_DIR)/TestPartitionedGraph.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_graph
	./$(BIN_DIR)/test_partitioned_graph


test-partitioned-graph: $(BIN_DIR)
	$(CHPL) $(TEST_DIR)/TestPartitionedGraph.chpl -M $(SRC_DIR) -o $(BIN_DIR)/test_partitioned_graph
	./$(BIN_DIR)/test_partitioned_graph
