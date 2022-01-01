# encoding: UTF-8
# frozen_string_literal: true
=begin

  Class MusicScore::Lilypond
  --------------------------
  Pour produire le code final à partir du code music-score

=end
class MusicScore
class Lilypond

CLE_TO_CLE_LILY = {
  'F' => 'bass', 'F3' => 'varbaritone',
  'G' => 'treble', 'G1' => 'french',
  'UT1' => 'soprano', 'UT2' => 'mezzosoprano',
  'UT3' => 'alto', 'UT4' => 'tenor', 'UT5' => 'baritone'
}

class << self

attr_reader :options

##
# = main =
#
# @return {String}  Le code complet à copier dans le fichier lilypond
#                   final, pour interprétation.
#
# @param {Array} code     Les lignes de code (code Lilypond)
# @param {Hash}  options  Les options
#     Note :  la méthode options.to_sym permet d'avoir les clés en
#             String et en Symbol, peu importe.
#
def compose(code, options)
  rationnalise_options(options)
  header + body(code, options[:system]) + footer
end

def rationnalise_options(options)
  #
  # Si les clés des portées sont définies, il faut les dispatcher
  #
  if options.key?('staves_keys')
    options['staves_keys'] = options['staves_keys'].split(',').collect{|n|n.strip}
  end
  #
  # Si les noms des portées sont définies, il faut les dispatcher
  #
  if options.key?('staves_names')
    options['staves_names'] = options['staves_names'].split(',').collect{|n|n.strip}
  end
  #
  # Si les clés ou les noms des portées sont définies, il faut
  # avoir les clés ET les noms
  #
  if options.key?('staves_keys') && !options.key?('staves_names')
    options.merge!('staves_names' => [])
  elsif options.key?('staves_names') && !options.key?('staves_keys')
    options.merge!('staves_keys' => [])
  end
  #
  # On ajoute les clés symboliques (donc on aura les deux versions
  # des clés dans la table)
  #
  @options = options.to_sym
end

##
# @return {String} Le corps du code en fonction du système choisi.
# 
# @param {String} system
#         Valeurs possible :
#         solo        Une seule portée
#         piano       Piano
#         quatuor     Quatuor à corde
#         Un nombre de portées.
#
def body(code, system)
  case system
  when 'solo', 'piano', 'quatuor' then send("system_for_#{system}", code)
  when Integer then system_for_x_staves(code)
  else
    raise EMusicScore.new("La valeur '#{system}' pour 'system' est intraitable… (inconnue)")
  end
end

def system_for_solo(code)
  <<-LILYPOND
<<
#{markin_transposition}\\relative c' {
  #{option_no_time}
  #{option_no_barre}
  #{option_no_stem}
  \\clef "treble"
  #{option_tonalite}
  #{option_num_mesure}
  #{code[0]}
}
>>
  LILYPOND
end
#/system_for_solo

def system_for_piano(code)
    <<-LILYPOND
\\new PianoStaff <<
  \\new Staff = "haute" {
    % enforce creation of all contexts at this point of time
    \\clef "treble"
    #{markin_transposition}\\relative c' {
      #{option_no_time}
      #{option_no_barre}
      #{option_no_stem}
      #{option_tonalite}
      #{option_num_mesure}
      #{code[0]}
    }
  }
  \\new Staff = "basse" {
    \\clef bass
    #{markin_transposition}\\relative c {
      #{option_no_time}
      #{option_no_barre}
      #{option_no_stem}
      #{option_tonalite}
      #{code[1]}
    }
  }
>>
  LILYPOND
end
#/system_for_piano

def system_for_x_staves(code)
  c = []
  c << "\\Score {"
  c << "  \\new StaffGroup <<"
  code.each_with_index do |code_portee, idx|
    c << staff_for(code_portee, {name:options['staves_names'][idx], key:options['staves_keys'][idx]})
  end
  c << "  >>"
  c << "}"

  return c.join("\n")
end
#/system_for_x_staves

def system_for_quatuor(code)
  <<-LILYPOND
\\Score {
  \\new StaffGroup <<
    #{staff_for(code[0], {name:'Violon 1'})}
    #{staff_for(code[1], {name:'Violon 2'})}
    #{staff_for(code[2], {name:'Alto',  key: 'alto'})}
    #{staff_for(code[3], {name:'Cello', key: 'bass'})}
  >>
}
  LILYPOND
end
#/system_for_quatuor

def staff_for(code, params)
  staff_name = ""
  if params[:name]
    staff_name = "\\set Staff.instrumentName = #\"#{params[:name]} \"\n"
  end
  relative = case params[:key]
  when 'F'    then ''
  when /^UT/  then "'"
  else "''"
  end
  staff_cle = params[:key] ? "\\clef #{CLE_TO_CLE_LILY[params[:key]]}\n" : ""
  <<-LILYPOND
\\new Staff <<
  \\new Voice #{markin_transposition}\\relative c#{relative} {
    #{staff_name}#{staff_cle}
    #{option_no_time}
    #{option_no_barre}
    #{option_no_stem}
    #{option_tonalite}
    #{option_num_mesure}
    #{code}
  }
>>
  LILYPOND
end

def header
  <<-LILYPOND
\\version "2.18.2"

#(set-default-paper-size #{option_page_format})

\\paper{
  indent=0\\mm
  oddFooterMarkup=##f
  oddHeaderMarkup=##f
  bookTitleMarkup = ##f
  scoreTitleMarkup = ##f
}

\\layout {
  \\context {
    #{option_staves_spacing}
    #{option_proximity}
  }
}

  LILYPOND
end
#/header

def footer
  <<-LILYPOND

#{option_espacements}

  LILYPOND
end
#/footer

def option_staves_spacing
  if options[:staves_spacing]
    <<-TEXT
    \\Staff
      \\override VerticalAxisGroup
      .staff-staff-spacing.basic-distance = #{options[:staves_spacing]}
    TEXT
  else "" end
end

def option_proximity
  if options[:proximity]
    <<-TEXT
    \\Score
      \\override SpacingSpanner.common-shortest-duration = #(ly:make-moment 1/#{options[:proximity]})
    TEXT
  else "" end
end

def option_page_format
  options[:page] ? options[:page] : '"a0" \'landscape'
end
def option_num_mesure
  options[:mesure] ? premier_numero_mesure : ""
end
def premier_numero_mesure
  <<-TXT
\\set Score.barNumberVisibility = #all-bar-numbers-visible
\\set Score.currentBarNumber = ##{options[:mesure]}
\\bar "" % pour qu'il s'affiche
  TXT
end
def option_no_time
  case options[:time]
  when true then ''
  when nil  then '\\omit Staff.TimeSignature'
  else '\\time ' + options[:time]
  end
  # options[:time] ? '' : '\\omit Staff.TimeSignature'
end
def option_no_barre
  options[:barres] ? '' : '\\override Score.BarLine.break-visibility = #all-invisible'
end
def option_no_stem
  options[:no_stem] ? '\\override Voice.Stem.transparent = ##t' : ''
end
def option_tonalite
  return '' if not options[:key]
  tune = options[:key]
  if tune.length == 2
    note, nature = options[:key].split('')
  else
    note, nature = options[:key].split('')
  end
  alter  = case nature
  when '#' then 'is'
  when 'b' then 'es'
  when 'es', 'is' then nature
  else ''
  end
  "\\key #{note.downcase}#{alter} \\major"
end
def option_espacements
  subdiv = 
  if options[:biggest_hspace]
    256
  elsif options[:big_hspace]
    128
  elsif options[:hspace]
    64
  elsif options[:mini_hspace]
    32
  else
    nil
  end
  return '' if subdiv.nil?
  <<-LPOND
\\layout {
 \\context {
   \\Score
   \\override SpacingSpanner.base-shortest-duration = #(ly:make-moment 1/#{subdiv})
 }
}

  LPOND
end


##
# Méthodes quand on doit transposer le fragment
def markin_transposition
  options[:transpose] ? "\\transpose #{options[:transpose]} " : "" 
end


# --- MÉTHODES DE TRANSLATION DU CODE MUSIC-SCORE VERS LILYPOND ---
##
# = main =
#
# Traduit un code music-score en un code Lilypond conforme
#
def translate_from_music_score(str)
  str = " #{str} "

  str = translate_barres_from_ms(str)

  str = translate_keys_from_ms(str)

  str = translate_nuplets_from_ms(str)

  str = translate_trilles_from_ms(str)

  str = translate_graces_notes_from_ms(str)

  str = translate_staff_change_from_ms(str)

  # On échappe toutes les balances
  str = str.gsub(/\\/, '\\')

  return str
end

private

  def translate_barres_from_ms(str)
    # Les barres de reprise sont simplement mises en '|:', ':|:' ou ':|'
    str = str.gsub(/:\|:/, '_DOUBLE_BARRES_REPRISE_')
          .gsub(/\|:/, '\bar ".|:"')
          .gsub(/:\|/, '_BARRES_REPRISE_FIN_')
          .gsub(/\|\./, '\bar "|."')
          .gsub(/\|\|/, '\bar "||"')
    str = str.gsub(/_DOUBLE_BARRES_REPRISE_/, '\bar ":|.|:"')
    str = str.gsub(/_BARRES_REPRISE_FIN_/, '\bar ":|."')
    return str
  end

  def translate_keys_from_ms(str)
    # Les clés, qui peuvent être précisées par '\cle F' et '\cle G'
    # '\clef F3'
    str.gsub(/\\clef? ((?:F|G|UT)[1-5]?) /){
      mark_cle = $1.freeze
      "\\clef \"#{CLE_TO_CLE_LILY[mark_cle]}\" "
    }
  end

  def translate_nuplets_from_ms(str)
    # Les triolets et autres quintolets qui peuvent 
    # s'écrire '3{note note note}', '5{note note note note note}'
    str.gsub(/([357])\{(.+?)\}/){
      notes = $2.strip.freeze
      deno  = $1.to_i.freeze
      sur   = deno - 1
      "\\tuplet #{deno}/#{sur} { #{notes} }"
    }    
  end


  def translate_trilles_from_ms(str)
    # === LES TRILLES ===
    #
    # La formule complexe 'a \tr-(gis32 a) b \-tr'
    # Ou plutôt : \tr(a'1)- (gis32 a)\-tr b1 
    # qui doit donner : \afterGrace a'1\startTrillSpan { gis32[ a]\stopTrillSpan } b1
    # 
    # On peut avoir au départ '\tr(cis dis)' pour triller avec une note étrangère
    str = str.gsub(/\\tr\((.*?)\)\-(.*?)\((.*?)\)\\\-tr/){
      seq = [] # pour construire le texte
      seq << '\afterGrace '
      notesdep = $1.freeze.split(' ')
      note_depart = notesdep.shift
      note_trilled = notesdep.count > 0 ? notesdep[0] : nil
      if note_trilled
        seq << '\pitchedTrill '
      end
      seq << note_depart
      seq << '\startTrillSpan '
      if note_trilled
        seq << note_trilled + ' '
      end
      inter_notes   = $2.freeze
      seq << inter_notes
      gnotes  = $3.freeze.split(' ')
      seq << '{ '
      seq << gnotes.shift
      if gnotes.count > 0
        seq << '[ ' + gnotes.join(' ') + ']'
      end
      seq << '\stopTrillSpan }'
      # texte à retourner
      puts "SEQ = #{seq.join('')}"
      seq.join('')
    }
    str = str.gsub(/\\tr\((.*?)\) /){
      n = $1.freeze.split(' ')
      if n.count == 1
        n.first + ' \trill ' # ne pas oublier l'espace
      else
        # On a donné la note avec laquelle il faut triller
        '\pitchedTrill ' + n[0] + '\startTrillSpan ' + n[1] + '\stopTrillSpan ' # ne pas oublier l'
      end
    }
    str.gsub(/\\tr\((.*?)\)\-/, '\1 \startTrillSpan')
      .gsub(/\\\-tr/, '\stopTrillSpan')
      .gsub(/\\tr\((.*?)\)/, '\1 \trill')
  end


  # === LES GRACES NOTES ===
  # Notation : \gr(<note>) <note>
  # Exemple  : '\gr(b8) a g16 f e1' qui va faire de b8 une grâce
  # <note>:
  #   - peut se finir par '/-'  => acciaccatura
  #   - peut se finir par '-'   => appoggiatura
  #   - peut se finir par '/'   => shaded grace
  #   - peut contenir une ou plusieurs notes
  def translate_graces_notes_from_ms(str)
    str.gsub(/\\gr\((.*?)\)/) do
      note = $1.freeze # Peut-être plusieurs notes
      only_notes = note.sub(/[\/\-]{1,2}$/,'').split(' ')
      # puts "only_notes = #{only_notes.inspect}"
      first_note = only_notes.shift
      all_notes = if only_notes.count > 0 
        '{ ' + first_note + ' ' + only_notes.join(' ') + ' }'
      else
        first_note
      end
      seq = if note.end_with?('/-')
        '\acciaccatura'
      elsif note.end_with?('/')
        '\slashedGrace'
      elsif note.end_with?('-')
        '\appoggiatura'
      else
        '\grace'
      end + ' ' + all_notes
      # puts "SEQ = #{seq}"
      seq
    end
  end

  # Changement de portée
  #  Phaut => \change Staff = "up"
  #  Pbas => \change Staff = "down"
  def translate_staff_change_from_ms(str)
    str = str.gsub(/(Phaut|\\up)/, '\change Staff = "haute"').gsub(/(Pbas|\\down)/, '\change Staff = "basse"')
  end

end #/<< self
end #/Lilypond
end #/MusicScore
