#!/bin/bash

# Function to check if Kafka is running
is_kafka_running() {
    docker ps | grep -q "cp-kafka"
}

# Function to create Kafka topics
create_topics() {
    echo "Creating Kafka topics..."
    TOPICS=(
        "chunk_embed_in" "chunk_embed_out"
        "convert_pdf_in" "convert_pdf_out"
        "index_upload_in" "index_upload_out"
        "ocr_summary_in" "ocr_summary_out"
        "query_processing_in" "query_processing_out"
        "document_retrieval_in" "document_retrieval_out"
        "answer_generation_in" "answer_generation_out"
        "web_crawler_in" "web_crawler_out"
    )

    for topic in "${TOPICS[@]}"; do
        docker exec kafka-1 kafka-topics --create --if-not-exists \
            --topic "$topic" --bootstrap-server kafka-1:9091,kafka-2:9092,kafka-3:9093 \
            --replication-factor 3 --partitions 1
    done
    echo "Kafka topics created successfully."
}

# Function to reset offsets for all consumer groups
reset_offsets() {
    echo "Resetting offsets for all consumer groups..."

    CONSUMER_GROUPS=(
        "chunk_embed_consumer"
        "convert_pdf_consumer"
        "index_upload_consumer"
        "ocr_summary_consumer"
        "query_processing_consumer"
        "document_retrieval_consumer"
        "answer_generation_consumer"
        "web_crawler_consumer"
    )

    for group in "${CONSUMER_GROUPS[@]}"; do
        echo "Resetting offsets for consumer group: $group"
        docker exec kafka-1 kafka-consumer-groups --bootstrap-server kafka-1:9091,kafka-2:9092,kafka-3:9093 \
            --group "$group" --reset-offsets --to-earliest --execute --all-topics
    done

    echo "Offsets for all consumer groups have been reset."
}

is_kafka_ui_running() {
    docker ps | grep -q "provectuslabs/kafka-ui"
}

# Main script execution
if is_kafka_running; then
    echo "Kafka is already running. Exiting."
    exit 1
else
    echo "Starting Kafka cluster..."
    docker compose -f docker-compose.yml up -d

    echo "Waiting for Kafka to be ready..."
    sleep 30  # Adjust this based on Kafka startup time

    create_topics
    reset_offsets  # Reset offsets automatically

    if is_kafka_ui_running; then
        echo "Kafka UI is already running. Skipping startup."
    else
        echo "Starting Kafka UI..."
        docker run -itd -p 8080:8080 -e DYNAMIC_CONFIG_ENABLED=true provectuslabs/kafka-ui
    fi

    echo "Kafka setup complete. You can now start consumers manually."
fi
