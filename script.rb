require 'fileutils'
require 'yaml'

def as_list(value)
  value = [value] if !value.kind_of?(Array)
  value
end

def make_translatable(hash, language, *keys)
  keys.each do |key|
    hash[key] = {language => hash[key]} if hash.has_key? key
  end
end

def translate(target, source, language, *keys)
  keys.each do |key|
    target[key][language] = source[key] if target.has_key?(key) && source.has_key?(key)
  end
end

# Create emtpy target folder
FileUtils.rm_rf 'target'
FileUtils.mkdir_p 'target'

# Detect all codelists in src folder
Dir.glob("src/**/codelist.yaml").filter { |s| !s.include? 'i18n' }.each do |source|
  # Find codelist folder
  folder = File.dirname source

  # Read metadata
  metadata = YAML.load_file source

  # Prepare metadata
  make_translatable metadata, metadata['language'], 'title', 'description'

  # Prepare holder of revisions
  revisions = Hash::new
  revisions_index = Hash::new

  Dir.glob("#{folder}/revision/*.yaml").each do |rev_source|
    rev_key = File.basename(rev_source)[0..-6]

    # Read revision
    rev = YAML.load_file rev_source

    index = Hash::new

    # Prepare codes
    rev['codes'].each do |code|
      code['id'] = code['id'].to_s
      make_translatable code, metadata['language'], *code.keys.filter { |key| key != 'id' }

      # Add to index
      index[code['id']] = code
    end

    # Store revision
    revisions[rev_key] = rev
    revisions_index[rev_key] = index
  end

  # Handle translations
  if File.directory? File.join(folder, 'i18n')
    metadata['translations'] = []

    Dir.glob(File.join(folder, 'i18n', '*')).map { |path| File.basename path }.sort.each do |language|
      # Add language to list of languages
      metadata['translations'].append language

      # Translated codelist metadata
      lm_path = File.join folder, 'i18n', language, 'codelist.yaml'
      if File.file? lm_path
        # Read translated metadata
        lm = YAML.load_file lm_path

        # Copy translated fields
        translate metadata, lm, language, 'title', 'description'
      end

      # Loop through translated revisions
      revisions.keys.each do |rev|
        lr_path = File.join folder, 'i18n', language, "#{rev}.yaml"
        if File.file? lr_path
          # Read translated metadata
          lr = YAML.load_file lr_path

          # Translate codes
          lr.each do |code|
            id = code['id'].to_s

            if revisions_index[rev].has_key? id
              translate revisions_index[rev][id], code, language, *code.keys.filter { |key| key != 'id' }
            end
          end
        end
      end
    end
  end

  # Write revisions
  revisions.values.each do |rev|
    # Prepare target filename
    target = File.join 'target', 'codelist', File.dirname(folder[4..-1]), "#{metadata['identifier']}-#{rev['identifier']}.yaml"

    # Write codelist
    FileUtils.mkdir_p File.dirname target
    File.write target, metadata.merge(rev).to_yaml(:line_width => -1)[4..-1]
  end

  # Create subsets
  Dir.glob(File.join(folder, 'subset', '*.yaml')).each do |sub_path|
    sub_id = File.basename(sub_path)[0..-6]
    sub = YAML.load_file sub_path

    # Prepare metadata for subset
    sub_metadata = sub.select { |key| ['name', 'agency'].include? key }

    # Make sure keys are strings
    sub['codes'] = sub['codes'].map { |code| code.to_s }

    as_list(sub['version']).map { |version| version.to_s }.each do |sr|
      rev = revisions[sr].clone

      # Create subset of codes
      rev['codes'] = rev['codes'].filter { |code| sub['codes'].include? code['id'] }

      # Prepare target filename
      target = File.join 'target', 'codelist', File.dirname(folder[4..-1]), "#{metadata['identifier']}-#{rev['identifier']}@#{sub_id}.yaml"

      # Write codelist
      FileUtils.mkdir_p File.dirname target
      File.write target, metadata.merge({'subset' => sub_metadata}).merge(rev).to_yaml(:line_width => -1)[4..-1]
    end
  end

end