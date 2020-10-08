require 'libreconv'

doc_path = "." + ARGV[0]
pdf_path = "." + ARGV[1]

Libreconv.convert(doc_path, pdf_path)
