import re
from typing import List, Tuple
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

class SpamFilter:
    def __init__(self, similarity_threshold: float = 0.70):
        self.threshold = similarity_threshold
        # Custom analyzer to handle both Devanagari (Nepali) and English characters elegantly
        self.vectorizer = TfidfVectorizer(
            token_pattern=r'(?u)\b\w+\b',
            ngram_range=(1, 2),
            stop_words=None  # We don't exclude default english stop words since Nepali text contains custom syntax
        )

    def clean_text(self, text: str) -> str:
        """Cleans and standardizes text input (removes special symbols)."""
        if not text:
            return ""
        # Remove extra whitespace and special characters except words and Devanagari ranges
        text = text.lower().strip()
        text = re.sub(r'[^\w\s\u0900-\u097F]', '', text)
        return text

    def check_duplicate(self, new_report_text: str, existing_reports: List[str]) -> Tuple[bool, float]:
        """
        Calculates the Cosine Similarity between a new report and existing reports.
        Returns:
            is_duplicate (bool): True if cosine similarity exceeds threshold.
            highest_score (float): The maximum similarity score found.
        """
        new_cleaned = self.clean_text(new_report_text)
        if not new_cleaned or len(new_cleaned) < 5:
            return True, 1.0  # Empty or too short text is classified as invalid/spam
            
        if not existing_reports:
            return False, 0.0

        cleaned_corpus = [self.clean_text(rep) for rep in existing_reports if rep]
        if not cleaned_corpus:
            return False, 0.0

        try:
            # Combine corpus and new text
            corpus = cleaned_corpus + [new_cleaned]
            
            # Fit and transform
            tfidf_matrix = self.vectorizer.fit_transform(corpus)
            
            # Compute cosine similarity between the last element (new text) and the rest of the corpus
            similarities = cosine_similarity(tfidf_matrix[-1], tfidf_matrix[:-1])[0]
            
            if len(similarities) == 0:
                return False, 0.0
                
            highest_score = float(max(similarities))
            is_duplicate = highest_score >= self.threshold
            
            return is_duplicate, highest_score
        except Exception as e:
            print(f"Error during TF-IDF calculation: {e}")
            # Safe fallback if vectorizer fails (e.g. empty vocab)
            return False, 0.0

# Singleton instance
spam_filter = SpamFilter()
