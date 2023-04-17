require 'mysql2'
require 'OpenAi'
require 'dotenv/load'
require 'json'
require 'matrix'

# データベース接続情報
CONFIG = {
  host: 'localhost',
  username: 'root',
  password: '',
  database: 'embedding_development'
}.freeze

def prompt(documents, input)
  <<~EOS
  Read the following text and answer the question.

  ## Text
  #{documents}

  ## Question
  #{input}
  EOS
end

client = Mysql2::Client.new(CONFIG)
openai_client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

def preprocess_text(text)
  text.gsub("\n", ' ').gsub(/\s+/, ' ').strip
end

def embed_text(text, openai_client)
  response = openai_client.embeddings(
    parameters: {
      model: "text-embedding-ada-002",
      input: [text]
    }
  )

  response['data'][0]['embedding']
end

def cosine_similarity(a, b)
  a_vector = Vector[*a]
  b_vector = Vector[*b]
  dot_product = a_vector.inner_product(b_vector)
  norm_a = a_vector.r
  norm_b = b_vector.r
  dot_product / (norm_a * norm_b)
end

def sorted_similar_chunks(query_vector, client)
  similarities = []
  client.query("SELECT chunk, vector FROM documents").each do |row|
    chunk = row['chunk']
    vector = JSON.parse(row['vector'], symbolize_names: true)
    similarity = cosine_similarity(query_vector, vector)
    similarities << {chunk: chunk, similarity: similarity}
  end
  similarities.sort_by! { |item| -item[:similarity] }.map { |item| item[:chunk] }
end

def send_chat_request(prompt, openai_client)
  response = openai_client.chat(
    parameters: {
      model: 'gpt-3.5-turbo',
      messages: [
        { role: 'user', content: prompt }
      ]
    }
  )

  response['choices'][0]['message']['content']
end

# 3. Get user input and embed it
puts 'Please enter a query:'

input = $stdin.gets

query_vector = embed_text(preprocess_text(input), openai_client)

# 4. Calculate cosine similarity and find the most similar chunk and vector
sorted_similar_chunks(query_vector, client)

# 5. Concatenate input and most similar chunk and send a request to Chat API
request_documents = sorted_similar_chunks(query_vector, client).take(5).join

response_text = send_chat_request(prompt(request_documents, input), openai_client)

# 6. Output response from Chat API
puts "Response: #{response_text}"
