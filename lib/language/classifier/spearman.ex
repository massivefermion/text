defmodule Text.Language.Classifier.Spearman do
  alias Text.Vocabulary

  @min_fit 0.55

  @doc """
  Correlation based upon the
  Spearman coefficient.

  """
  def score_one_language(language, ngrams, vocabulary) do
    language_vocab = vocabulary.get_vocabulary(language)

    # Deal only with ngrams in common and re-rank them
    vocab =
      language_vocab
      |> Enum.filter(fn {ngram, _} -> Map.get(ngrams, ngram) end)
      |> Vocabulary.order_by_count()
      |> Enum.with_index(1)
      |> Enum.map(fn {{ngram, ngram_stats}, index} ->
        {ngram, %{ngram_stats | rank: index}}
      end)
      |> Map.new()

    text_ngrams =
      ngrams
      |> Enum.filter(fn {ngram, _} -> Map.get(vocab, ngram) end)
      |> Vocabulary.order_by_count()
      |> Enum.with_index(1)
      |> Enum.map(fn {{ngram, ngram_stats}, index} ->
        {ngram, %{ngram_stats | rank: index}}
      end)
      |> Map.new()

    percentage_retained = Enum.count(Map.keys(text_ngrams)) / Enum.count(Map.keys(ngrams))

    # Omit those languages where the number of target ngrams is very
    # low compared to the original ngrams -> means not a lot of overlap
    # between the text ngram list and the vocab ngram list
    if percentage_retained > @min_fit do
      squares =
        text_ngrams
        |> Enum.map(fn {ngram, %{rank: text_rank}} ->
          %{rank: vocab_rank} = Map.get(vocab, ngram)
          (vocab_rank - text_rank) * (vocab_rank - text_rank)
        end)

      n = Enum.count(squares)
      sum_of_squares = Enum.sum(squares)

      score = 1 - 6 * sum_of_squares / (n * (n * n - 1))
      {language, score}
    else
      {language, :no_fit}
    end
  end

  def pad(ngram) do
    l = 4 - length(ngram)
    List.duplicate(?\s, l)
    [ngram | List.duplicate(?\s, l)]
  end

  @doc """
  Return the `{language score}` tuples
  in the correct order for this classifier.

  """
  def order_scores(score) do
    score
    |> Enum.reject(fn {_, score} -> score == :no_fit end)
    |> Enum.sort(fn {_, score1}, {_, score2} -> score1 > score2 end)
  end
end
