def read_plane_data(file_name)
  File.read(file_name).gsub(/[\n\s]+/, ' ').strip
end

def save_chunks_and_vectors_to_mysql(plane_data, client, openai_client)
  plane_data.scan(/.{1,500}/m).each do |chunk|
    vector = embed_text(chunk, openai_client)
    client.query("INSERT INTO documents (chunk, vector) VALUES ('#{client.escape(chunk)}', '#{JSON.generate(vector)}')")
  end
end

# 1. Load plane_data.txt
plane_data = read_plane_data('plane_data.txt')

# 2. Save chunks and vectors to MySQL
save_chunks_and_vectors_to_mysql(plane_data, client, openai_client)
