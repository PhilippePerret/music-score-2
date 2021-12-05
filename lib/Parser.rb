# encoding: UTF-8
# frozen_string_literal: true
=begin

  Module qui s'occupe de parser le code fourni, qu'il provienne d'un
  fichier ou de la ligne de commande

=end
class MusicScore
class Parser

attr_reader :music_score

# 
# {Array} La liste de tous les blocs de code où toutes les définitions et
# autres traitements ont été appliqués. Chaque élément est une 
# instance BlockCode
attr_reader :all_blocks

##
# Instanciation du parser, avec l'instance MusicScore +music_score
#
def initialize(music_score)
  @music_score = music_score
end

##
# @usage MusicScore::Parser.exec
#
#
# Produit :
#   - les "définitions" qui sont des lignes de code associées à un
#     nom de variable.
#   - les segments d'image
#
def parse
  code = ini_code
  #
  # Suppression des commentaires
  #
  code = code.gsub(/^#(.*)$/,'')
  #
  # Réducation des retours chariot
  # 
  code = code.gsub(/\n\n\n+/, "\n\n").strip

  #
  # Les options courantes
  #
  options = {definitions_globales:{}, definitions_locales:{}}

  #
  # Pour mettre tous les blocs de code
  #
  all_blocks = []

  # Découpe du code en "paragraphes" qui définissent chacun quelque
  # chose.
  code.split("\n\n").each do |paragraphe|
    blocode = BlockCode.new(paragraphe, options.merge(music_score:music_score))
    blocode.parse
    options = blocode.options

    #
    # On retire les options ponctuelles
    #
    [:mesure,:proximity].each{|k|options.delete(k)}

    #
    # Cas spécial où il faut seulement parser à partir de là
    #
    if blocode.start?
      # TODO Vider les données récoltées jusque-là
      all_blocks = []
    end

    #
    # Cas spécial où il faut s'arrêter de parser là
    #
    if blocode.stop?
      break
    end

    # 
    # En fonction de la nature de ce bloc de code, on le range 
    # à différents endroits.
    #
    if blocode.definition?
      if blocode.global?
        options[:definitions_globales].merge!( blocode.definition_name => blocode)
      else
        options[:definitions_locales].merge!( blocode.definition_name => blocode)
      end
    elsif blocode.only_options?
      # 
      # Seulement des options
      # => on ne fait rien
      #
    else
      # 
      # En dernier recours, on ajoute le bloc de code courant
      #
      all_blocks << blocode
      #
      # Et on ré-initialise les définitions locales
      #
      options[:definitions_locales] = {}
    end

    # puts "PARA : #{blocode.inspect}"
    # puts "OPTIONS : #{options.inspect}"
  end

  @all_blocks = all_blocks
end
#/parse

def ini_code
  @ini_code ||= music_score.expression.gsub(/\r?\n/, "\n").strip
end

end #/Parser
end #/MusicScore
