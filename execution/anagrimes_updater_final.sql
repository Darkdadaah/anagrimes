SELECT '- Replace the old tables by the new ones' AS '' ;
RENAME TABLE    articles TO articles_old,
                articles_temp TO articles,
		mots TO mots_old,
                mots_temp TO mots,
		langues TO langues_old,
                langues_temp TO langues ;

SELECT '- Drop the old tables' AS '' ;
DROP TABLE articles_old, mots_old, langues_old ;

SELECT 'DONE' AS '' ;
