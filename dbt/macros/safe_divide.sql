{% macro safe_divide(numerator, denominator) %}
    {% if target.type == 'snowflake' %}
        div0({{ numerator }}, {{ denominator }})
    {% else %}
        ({{ numerator }}) / nullif(({{ denominator }}), 0)
    {% endif %}
{% endmacro %}
