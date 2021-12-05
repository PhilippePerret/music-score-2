# encoding: UTF-8
# frozen_string_literal: true
=begin

  MusicScore 
  ------------
  La classe principale

=end
class MusicScore
class << self
  attr_accessor :options
  def init
    @options = {
      verbose: false
    }
  end

  def show_help
    help_pdf = File.expand_path(File.join(__dir__,'..','Manuel','Manuel.pdf'))
    `open "#{help_pdf}"`
  end

  def verbose?
    options[:verbose]
  end
end #/<< self

# --- INSTANCE ---

#
# Les options générales (de la ligne de commande)
#
attr_reader :options

#
# L'expression fournie. C'est toujours le code.
#
attr_reader :expression

#
# Le chemin d'accès au fichier .mus, si c'est un fichier qui a
# été fourni.
# 
attr_reader :mus_file

#
# Le parser
#
# Il contient notamment :options et :all_blocks qui contient tous
# les blocs qui vont produire autant d'images.
#
attr_reader :parser

##
# = main =
#
# Point d'entrée du programme
#
# La méthode analyse les arguments fournis pour en tirer les 
# conclusion sur le code à analyser et les options à garder.
#
# La méthode peut être appelée avec :options et :expression.
#
def proceed(params = nil)
  #
  # Parse de la ligne de commande
  #
  if params.nil?
    parse_command_line
  else
    @options    = params.options
    @expression = params.expression
    @mus_file   = MusFile.new(params.path)
  end

  self.class.options.merge!(options)

  # Débug
  debug_self_attributes if verbose?

  #
  # Analyse de l'expression fournie (elle peut être longue)
  #
  parse_expression

  if verbose?
    puts "CODE FINAL: \n#{parser.all_blocks.collect{|bc|bc.lines_code.inspect}.join("\n")}"
  end

  #
  # À chaque "bloc de code" obtenu correspond une "sortie", qui est
  # la plupart du temps une image.
  # On l'instancie et on la construit.
  # 
  parser.all_blocks.each do |bloccode|
    ms_image = Output.new(bloccode)
    ms_image.build_if_required
  end

end

##
# Analyse de la ligne de commande fournie. Elle peut contenir :
#   - des options (-/--)
#   - du code music-score
#     OU Le chemin d'accès au fichier .mus à traiter.
#
def parse_command_line
  @options = {}
  exp = []
  ARGV.each do |argv|
    puts "Traitement de l'argument #{argv.inspect}" if verbose?
    if argv.start_with?('-')
      # 
      # <= L'argument commence par un '-'
      # => C'est forcément une option (longue ou courte ?)
      #
      if argv.start_with?('--')
        @options.merge!(argv[2..-1].to_sym => true)
      elsif argv.start_with?('-')
        argv = argv[1..-1]
        @options.merge!(SHORT_OPTION_TO_LONG[argv] => true)
      end
    else
      #
      # Soit le code, soit une expression pseudo-lilypond (donc une
      # expression music-score)
      #
      exp << argv
    end
  end
  exp = exp.join(' ')

  #
  # Analyse de l'expression pour savoir si c'est un chemin d'accès
  # ou du code music-score.
  #
  # Attention : comme le code n'est pas toujours évalué dans ce
  # dossier, un chemin relatif ("./...") ne sera pas forcément trouvé
  #
  if File.exist?(exp) || exp.start_with?('./')
    @mus_file   = MusFile.new(exp)
    @expression = @mus_file.ms_code
  else
    @expression = exp
  end
end
#/parse_command_line

##
# Instancie un parser pour parser l'expression fournie et parse le
# code (l'expression)
#
def parse_expression
  @parser = Parser.new(self)
  @parser.parse
end

# --- options ---

def verbose?
  @options[:verbose]
end


private


  #
  # Simplement pour débugger les valeurs si on ajoute -v à la ligne
  # de commandes
  #
  def debug_self_attributes
    puts "Options:    #{options.inspect}".mauve
    puts "Expresion : #{expression.inspect}".mauve
    puts "Fichier   : #{mus_file.inspect}".mauve  
  end

end #/MusicScore
