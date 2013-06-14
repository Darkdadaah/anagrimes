SELECT '- Move the old tables back' AS '' ;
RENAME TABLE    articles TO articles_temp,
                articles_old TO articles,
		mots TO mots_temp,
                mots_old TO mots,
		langues TO langues_temp,
                langues_old TO langues ;

