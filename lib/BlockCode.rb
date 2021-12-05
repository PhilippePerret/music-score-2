# encoding: UTF-8
# frozen_string_literal: true
=begin

  Class MusicScore::Parser::BlockCode
  -----------------------------------
  Pour un bloc de code, un paragraphe

  Un bloc de code peut être de différentes nature :

    - une option seule (par exemple une ligne contenant '--piano OFF')
    - plusieurs options seules
    - la définition d'une image ('->', mais pas forcément au début)
    - une définition de variable (la première ligne est forcément
      terminée par un '=' ou un '==')
    - une commande (--start, --stop)

=end
class MusicScore
class Parser
class BlockCode


  # L'expression régulière qui traque les séquences d'images
  REG_SEQUENCE_IMAGES = /\b([a-zA-Z]+)([0-9]+?)<\->([0-9]+?)\b/

attr_reader :raw_code
attr_reader :options
attr_reader :lines_code
#
# Si définition
#
attr_reader :definition_name

#
# Si image
#
attr_reader :image_name

##
# Instanciation du bloc de code avec son contenu et les options
# courantes
#
# @param  raw_code {String}
#         Le code (pseudo lilypond = music-score)
# @param  options {Hash}
#         Les options en court. Elles pourront être modifiée par
#         l'analyse du bloc de code
#
def initialize(raw_code, options)
  @raw_code = raw_code
  @options  = options.dup
end

# --- Méthodes de statut ---

def definition?
  !@definition_name.nil?
end
def global? # si définition
  definition? && @is_global_definition
end
def local?  # si définition
  definition? && !@is_global_definition
end

def only_options?
  @lines_code.count == 0
end

def start?
  options[:start]
end

def stop?
  options[:stop]
end

##
# Analyse du raw_code
#
# On passe chaque ligne en revue
#
def parse
  #
  # Les lignes de code de musique
  #
  @lines_code = []

  if verbose?
    puts "Raw code étudié :\n<<<<<<<<<\n#{raw_code}\n>>>>>>>>>>>>\n"
  end

  lines = raw_code.split("\n")

  #
  # Est-ce une définition ?
  #
  if lines[0].match?(/^[a-zA-Z0-9_]+\=\=?$/)
    # 
    # <= La première ligne termine par '=' ou '=='
    # => C'est une définition
    #
    line1 = lines.shift
    if line1.end_with?('==')
      @is_global_definition = true
      @definition_name = line1[0..-3]
    else
      @is_global_definition = false
      @definition_name = line1[0..-2]
    end
  end

  #
  # Boucle sur toutes les lignes à traiter
  # (souvent, il n'y en a qu'une ou deux — piano)
  #
  lines.each do |line|
    line = line.strip
    if line.start_with?('->')
      #
      # Définition du nom de l'image
      #
      @image_name = line[2..-1].strip
    elsif line.start_with?('--')
      # 
      # Définition d'une option
      #
      traite_as_option(line[2..-1])
    else
      #
      # Définition d'une ligne de code music-score
      #
      @lines_code << line
    end
  end

  # On doit maintenant remplacer les variables dans chaque ligne
  #
  lines = []
  @lines_code.each_with_index do |line, idx|
    lines << traite_as_code_mscore(line, idx)
  end

  @lines_code = lines

end

##
# On traite la ligne comme une ligne de code
def traite_as_code_mscore(line, idx)
  line = traite_definitions_in(line, idx)
end

def traite_as_option(opt)
  opt, setting = opt.split(' ')
  val = case setting
    when 'OFF', 'Off', 'off' then false
    when nil then true
    else setting # la valeur de l'option, p.e. pour mesure, ou time
    end

  # Quelques correspondances de clé et correction de
  # valeurs
  # Note : s'il vient à y en avoir beaucoup, on les mettra dans
  # une table.
  case opt
  when 'page' then val = "\"#{val}\""
  when 'tune' then opt = 'key'
  when 'proximity'
    if val.match?('-')
      # C'est un rang de proximités, il faut produire une 
      # image pour chaque valeur
      from, to = val.split('-').collect{|i|i.to_i}
      val = (from..to)
    end
  end

  options.merge!(opt => val)
end
#/traite_option


# 
# Remplacement des définitions dans +str+
# 
# @return {String}  La ligne de code avec les remplacements de 
#                   variables effectués.
#
# @param  {String} str La ligne de code
# @param  {Number} line_idx  Index de la ligne, pour savoir quelle ligne
#                       utiliser dans la définition.
def traite_definitions_in(str, line_idx)
  # puts "Je dois remplacer les définitions :\n\t#{DEFINITIONS.inspect}\net\n\t#{DEFINITIONS_GLOBALES.inspect}\ndans:\n\t#{str.inspect}"
  str = " #{str} "

  # Dans un premier temps, il faut remplacer les séquences de 
  # mesures sous la forme [img][index départ]<->[index fin] par les
  # mesures concernées
  if str.match?('<->')
    # puts "AVANT traitement séquence :\n#{str.freeze}"
    str = str.gsub(REG_SEQUENCE_IMAGES){
      prefix = $1.freeze
      index_start = $2.to_i.freeze
      index_stop  = $3.to_i.freeze
      (index_start..index_stop).collect do |index|
        "#{prefix}#{index}"
      end.join(' ')
    }
    # puts "\n\nAPRÈS traitement séquence :\n#{str}"
  end

  definitions = {}
  definitions.merge!(options[:definitions_locales])
  definitions.merge!(options[:definitions_globales])

  # puts "Définitions à traiter : #{definitions.inspect}"

  definitions.each do |search, blocode|
    str.match?(search) || next
    remp = blocode.lines_code[line_idx] || blocode.lines_code[0]
    # puts "remp: #{remp.inspect}::#{remp.class}"
    if not remp.is_a?(String)
      if remp.nil?
        puts "#ERREUR Variable #{search.inspect} mal définie".rouge
        puts "Chaine à transformer : #{str.inspect}".rouge
        puts "Ligne #{line_idx} absente dans :".rouge
        puts "#{blocode.lines_code.inspect}".rouge
        opts = options.dup
        opts.delete(:definitions_globales)
        opts.delete(:definitions_locales)
        opts.delete(:music_score)
        puts "Options : #{opts.inspect}".rouge
        raise "La définition de #{search.inspect} devrait définir la ligne #{line_idx +1}"
      else
        raise "La définition de #{search.inspect} n'est pas conforme…"
      end
    end
    # puts "remp = #{remp.inspect}"
    str = str.gsub(/ #{search} /, " \\relative c' { #{remp} } ")
             .gsub(/ #{search} /, " \\relative c' { #{remp} } ")
          # 2 fois car elles peuvent se toucher
  end

  str = str.strip

  # puts "STR final : #{str.inspect}"

  return str
end #/traite_definitions_in



end #/BlockCode
end #/Parser
end #/MusicScore
