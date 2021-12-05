# encoding: UTF-8
# frozen_string_literal: true


def mkdir(dossier)
  File.exist?(dossier) || `mkdir -p "#{dossier}"`
  dossier
end
